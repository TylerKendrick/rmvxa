=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Core
Version:    v0.9.3

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Core"] = "v0.9.3"

module Kendrick
  def self.require(values); Core.require(values); end    
        
  #=============================================================================
  # Kendrick::Errors : This module exists to build and provide common errors.
  #=============================================================================
  module Errors
    extend Enumerable
    
    class << self
      
      def default_errors
        return {
          :missing_method => ->(context, method) {
            # putting this in an actual Module#method destroys caller values.
            method ||= caller[0][/`.*'/][1..-2]
            missing_method(context, method)
          },
          :missing_script => method(:missing_script)
        }
      end
      
      def missing_method(context, method)
        message = "#{method} must be implemented on #{context}"
        ::NotImplementedError.new(message)
      end
      
      def missing_script(*args)
        args.as do |name, value, errorNo|
          ::ScriptError.new case errorNo
            when :exact_version then "missing script: #{name} #{value}"
            when :min_version then "script: #{name} requires minimum version #{value}"
            when :range_version then "script: #{name} must be between version range #{value.to_s}"
            when :bool_include
              include = value ? "should" : "shouldn't"
              message = "script: #{name} #{include} be included."
            else; "There was an error parsing the dependency: #{name}"
          end
        end
      end
      
      def each(&block); @@errors.each(&block); end
                
    end # class << self
    @@errors = ::Kendrick::Errors.default_errors

    def error(key, *args); 
      self.class[key].call(self, args); 
    end    
  end # Kendrick::Error
  
  #=============================================================================
  # Kendrick::Core
  #=============================================================================  
  module Core
    include Kendrick::Errors
    
    @@scripts = Hash.new { |h, k| h[k] = [] }
    Load_Method = :load_resources
    
    def self.load_data(path, result)
      result.tap do |x|
        m = ->(y) { y.try_method(Load_Method) }
        # RPG::System doesn't return an array.
        x.is_a?(::Array) ? x.compact.each(&m) : m.(x)
      end
    end
    
    def self.preload_database
      resolve_dependencies(&method(:error_handler))
    end
    
    def self.error_handler(*args)
      raise missing_script(*args)
    end
    
    #---------------------------------------------------------------------------
    # Reserved for aliasing.
    #---------------------------------------------------------------------------
    def self.load_database; end
    
    #---------------------------------------------------------------------------
    # This method is called by implemented classes to register a dependency.
    #---------------------------------------------------------------------------
    def self.require(values = {})
      values.each { |key, value|
        item = @@scripts[key]
        item << value unless item.include?(value)
      }
    end
    
    #---------------------------------------------------------------------------
    # This method is called by Kendrick::Core to handle dependencies.
    #---------------------------------------------------------------------------
    def self.resolve_dependencies(&on_error)
      return @@scripts.all? { |key, values|
        values.all? { |value| resolve_dependency(key, value, &on_error) }
      }
    end
    
    #---------------------------------------------------------------------------
    # Determines how to handle individual dependencies
    #---------------------------------------------------------------------------
    def self.resolve_dependency(name, value)
      $imported.has_key?(name).tap { |x|
        yield(name, value) if block_given? && !x
      }
    end    
  end # Kendrick::Core
  
  #=============================================================================
  # Kendrick::Observer : This class simply wraps a method for unsubscription 
  # from observables.
  #=============================================================================
  class Observer
        
    def initialize(&method); @method = method; end
    def call(*args, &block); @method.call(*args, &block); end    
  end # Kendrick::Observer
        
  #=============================================================================
  # Kendrick::Notifiable
  #=============================================================================
  module Notifiable
    
    def observers; @observers ||= []; end
    def notify(*args, &block)
      observers.each { |x| x.call(*args, &block) }
    end
    
  end # Kendrick::Notifiable
  
  #=============================================================================
  # ::Game_BaseItem
  #=============================================================================
  module Observable
    include Notifiable
    
    def subscribe(&m)
      create_observer(&m).tap(&observers.method(:<<))
    end
    
    def unsubscribe(observer); observers.delete(observer); end
    
    protected
    def create_observer(&m); Observer.new(&m); end
  end # Kendrick::Observable
  
end # Kendrick

#===============================================================================
# ::Game_BaseItem
#===============================================================================
class ::Game_BaseItem
  
  def id; @item_id; end
  
end # ::Game_BaseItem

#===============================================================================
# ::Game_Battler
#===============================================================================
class ::Game_Battler
  
  #-----------------------------------------------------------------------------
  # Determines if #current_action returns an ::RPG::Item instance.
  #-----------------------------------------------------------------------------
  def item?; current_action._?(:item)._?(:is_a?, ::RPG::Item); end
  
  #-----------------------------------------------------------------------------
  # Determines if #current_action returns an ::RPG::Skill instance.
  #-----------------------------------------------------------------------------
  def skill?; current_action._?(:item)._?(:is_a?, ::RPG::Skill); end
  
  #-----------------------------------------------------------------------------
  # Obtains the last used skill.
  #-----------------------------------------------------------------------------
  def skill; $data_skills[(skill? ? current_action.item : last_skill).id]; end
  
  #-----------------------------------------------------------------------------
  # Simplifies accessibility between classes "Game_Actor" and "Game_Enemy".
  #-----------------------------------------------------------------------------
  def data
    return actor if actor?
    return enemy if enemy?
  end
  
end # ::Game_Battler

#===============================================================================
# ::DataManager
#===============================================================================
module ::DataManager
  class << self
    
    alias :kendrick_load_database :load_database
    #---------------------------------------------------------------------------
    # Invokes the original #load_database with the new callback idiom.
    #---------------------------------------------------------------------------
    def load_database
      @callee ||= callee(:kendrick_load_database, {
        :before => ->(*args) { Kendrick::Core.preload_database },
        :complete => ->(status) { Kendrick::Core.load_database }
      })
      @callee.call
    end
    
    alias :registrar_load_data :load_data
    #---------------------------------------------------------------------------
    # Allows classes generated by #load_data to be intercepted on creation if
    # they implement #load_resources.  This is neccessary because Marshal loaded
    # objects don't call initialize and, therefore, cannot be overridden.
    #---------------------------------------------------------------------------
    def load_data(path)
      result = registrar_load_data(path)
      Kendrick::Core.load_data(path, result)
    end
    
  end # class << self
end # ::DataManager

#===============================================================================
# ::Kernal
#===============================================================================
class ::Kernal

  #-----------------------------------------------------------------------------
  # Tries to invoke a method if the context responsds to the symbol.
  #-----------------------------------------------------------------------------
  def self.try_method(context, symbol, *args, &block)
    context.respond_to?(symbol).tap { |x|
      context.send(symbol, *args).tap { |r| yield r if block_given? } if x
    }
  end

  #-----------------------------------------------------------------------------
  # Evaluates text and returns the expression as a lambda.
  #-----------------------------------------------------------------------------
  def self.eval_method(text, *args)
    eval("->(#{args.join(',')}){#{text}}")
  end
  
end # ::Kernal

#===============================================================================
# ::Object
#===============================================================================
class ::Object
    
  #-----------------------------------------------------------------------------
  # Obtains a method as a new Callee instance.
  #-----------------------------------------------------------------------------
  def callee(symbol, hash={}, &callback)
    method(symbol).to_callee(hash, &callback)
  end

  #-----------------------------------------------------------------------------
  # Invokes ::Kernal#try_method with the caller provided as the current context.
  #-----------------------------------------------------------------------------
  def try_method(method, *args)
    ::Kernal.try_method(self, method, *args)
  end
  
  #-----------------------------------------------------------------------------
  # Invokes ::Boolean#convert with the caller provided as the current context.
  #-----------------------------------------------------------------------------
  def to_b; ::Boolean.convert(self); end
  
  #-----------------------------------------------------------------------------
  # Simplifies multiple assignment operations as explicit block expressions.
  #-----------------------------------------------------------------------------
  def as; yield self; end

  #-----------------------------------------------------------------------------
  # Allows for safe navigation.  Simplifies null coalescing index expressions.
  #-----------------------------------------------------------------------------
  def maybe(*args, &block)
    is_a?(::NilClass) || !respond_to?(args.first) ? nil : send(*args, &block)
  end
  alias :_? :maybe
  
  def if(condition = !nil?); condition && block_given? ? yield(self) : self; end
  def unless(condition = !nil?, &block); self.if(!condition, &block); end
end # ::Object

#===============================================================================
# ::Callee
#===============================================================================
class ::Callee < ::Kendrick::Observer
  
  #-----------------------------------------------------------------------------
  # Creates and registers a new callback for the target method.
  #-----------------------------------------------------------------------------
  def subscribe(hash = {}, &options)
    @callbacks ||= []
    ::Callback.new(hash, &options).tap(&@callbacks.method(:<<))
  end
  
  #-----------------------------------------------------------------------------
  # Invokes a target method with exception handling provided by an options hash.
  #-----------------------------------------------------------------------------
  def call(*args)
    status = :not_modified
    if @callbacks.all? { |x| x.before(*args) }
    
      begin
        result = super
        @callbacks.each { |x| x.success(result) }
        status = :success
      rescue Exception => e
        status = :error
        @callbacks.each { |x| x.error(e, :error) }
      end
    
    end
    @callbacks.each { |x| x.complete(status) }
  end
  
end # ::Callee

#===============================================================================
# ::Callback
#===============================================================================
class Callback
  
  def self.options(hash = {}, &block)
    Options.new(hash, &block)
  end
  
  def initialize(hash = {}, &block)
    @options = Callback.options(hash, &block)
  end
    
  def before(*args);    @options.before.call(*args); end
  def error(*args);     @options.error.call(*args); end
  def success(*args);   @options.success.call(*args); end
  def complete(*args);  @options.complete.call(*args); end    
  
end # ::Callback

class Options
  
  def initialize(options = {})
    meta = class << self; self; end
    options.each { |key, value|
      sym = "@#{key}"
      instance_variable_set(sym, value)
      meta.send(:define_method, key) { |&b| accrue(sym, &b) }
    }
  end
  
  private
  alias :set :instance_variable_set
  alias :get :instance_variable_get
  def accrue(sym, &b); block_given? ? set(sym, &b) : get(sym); end
end

#===============================================================================
# Provides a common idiom for callback structures.
#===============================================================================
class ::Callback::Options < ::Options
  
  def self.before(*args);       true; end  
  def self.error(error, type);  raise error; end
  def self.success(data = nil); data; end  
  def self.complete(status);    status; end
  
  Hash = {
    :before => method(:before),
    :error => method(:error),
    :success => method(:success),
    :complete => method(:complete)
  }
  
  def initialize(options = {})
    super(Hash.merge(options || {}))
  end  
end

module Function

  def to_callee(hash={}, &options)
    ::Callee.new(&self).tap { |x| x.subscribe(hash, &options) }
  end
end

Method.send(:include, Function)
Proc.send(:include, Function)

class Symbol
  
  def to_callee(hash = {}, &options)
    to_proc.to_callee(hash, &options)
  end
end

#===============================================================================
# This module just makes handling and parsing booleans much easier.
#===============================================================================
module ::Boolean
  @@true_strings = ["True", "true", "T", "t"] # can append "yes"
  @@false_strings = ["False", "false", "F", "f"] # can append "no"
  
  #-----------------------------------------------------------------------------
  # Attempts a custom, overloadable, conversion of objects to ::Boolean.
  #-----------------------------------------------------------------------------
  def self.convert(object)
    case object
      when ::Numeric then object != 0
      when ::String then object.as { |x|
        !false_string?(x) && true_string?(x)
      }
      else; !!object
    end #case
  end #self.convert
  
  def self.false_string?(text); @@false_strings.include?(text); end
  def self.true_string?(text); @@true_strings.include?(text); end
end # ::Boolean

TrueClass.send(:include, ::Boolean)
FalseClass.send(:include, ::Boolean)

#===============================================================================
# This global method returns evaluated text as an anonymous Proc.
#===============================================================================
def eval_method(text, *args)
  ::Kernal.eval_method(text, *args)
end
