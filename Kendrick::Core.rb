=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Core
Version:    v0.9.2

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Core"] = "v0.9.2"

#===============================================================================
# Note: The Kendrick Module will contain all Kendrick scripts and addons as a 
# namespace prefix.
#===============================================================================
module Kendrick

  #=============================================================================
  # Note: Simplifies access for registering scripts.
  #=============================================================================
  def self.require(values = {})
    Core.require(values)
  end
  
  #=============================================================================
  # Note: This module exists to build and provide common errors.
  #=============================================================================
  module Errors
    class << self
      
      def build_errors
        return {
          :missing_method => ->(context, method) {
            # putting this in an actual Module#method destroys caller values.
            method ||= caller[0][/`.*'/][1..-2]
            return missing_method(context, method)
          },
          :missing_script => method(:missing_script)
        }
      end
      
      def missing_method(context, method)
        message = "#{method} must be implemented on #{context}"
        return ::NotImplementedError.new(message)
      end
      
      def missing_script(*args)
        name, value, errorNo = args
        
        case errorNo
          when :exact_version
            message = "missing script: #{name} #{value}"
          when :min_version
            message = "script: #{name} requires minimum version #{value}"
          when :range_version
            message = "script: #{name} must be between version range #{value.to_s}"
          when :bool_include
            include = value ? "should" : "shouldn't"
            message = "script: #{name} #{include} be included."
          else
            message = "There was an error parsing the dependency: #{name}"
        end
        
        ::ScriptError.new(message)
      end
      
      def [](index)
        return @@errors[index]
      end
          
    end # class << self

    @@errors = ::Kendrick::Errors.build_errors

    #---------------------------------------------------------------------------
    # This method is called by implemented classes to raise a common error.
    #---------------------------------------------------------------------------
    def error(key, *args)
      ::Kendrick::Errors[key].call(self, args)
    end    
    
  end # Kendrick::Error
  
  #=============================================================================
  # Note: This object contains the majority of data structures in use by
  # derived Kendrick Scripts.
  #=============================================================================  
  module Core
    include Kendrick::Errors
    
    @@scripts = {}
    Load_Method = :load_resources
    
    def self.load_data(path, result)
      # Most results of load_data return an array.
      if result.is_a?(::Array)
        # Some items are nil.  Remember to compact.
        result.compact.each { |x| x.try_method(Load_Method) }        
      else # RPG::System doesn't return an array.
        result.try_method(Load_Method)
      end      
      
      return result # Don't forget to return the original result.
    end
        
    #---------------------------------------------------------------------------
    # This method is used to ensure dependencies are included before loading
    # assets and data.
    #---------------------------------------------------------------------------
    def self.preload_database
      return resolve_dependencies { |name, value, errorNo|
        error_method = ::Kendrick::Errors[:missing_script]
        raise error_method.call(name, value, errorNo)
      }
    end
    
    #---------------------------------------------------------------------------
    # Reserved for aliasing.
    #---------------------------------------------------------------------------
    def self.load_database
    end
    
    #---------------------------------------------------------------------------
    # This method is called by implemented classes to register a dependency.
    #---------------------------------------------------------------------------
    def self.require(values = {})
      for pair in values do
        key, value = pair
        @@scripts[key] ||= []   
        item = @@scripts[key]
        item << value unless item.include?(value)
      end
    end
    
    #---------------------------------------------------------------------------
    # This method is called by Kendrick::Core to handle dependencies.
    #---------------------------------------------------------------------------
    def self.resolve_dependencies(&on_error)
      return @@scripts.all? { |pair|
        key, values = pair
        values.all? { |value| resolve_dependency(key, value, &on_error) }
      }
    end
    
    #---------------------------------------------------------------------------
    # Determines how to handle individual dependencies
    #---------------------------------------------------------------------------
    def self.resolve_dependency(name, value, &on_error)
      has_error = !$imported.has_key?(name)
      on_error.call(name, value) if has_error && on_error
      return has_error
    end
    
  end # Kendrick::Core
  
  #=============================================================================
  # Note: This class simply wraps a method for unsubscription from observables.
  #=============================================================================
  class Observer
        
    def initialize(&method)
      @method = method
    end
    
    def call(*args, &block)
      @method.call(*args, &block)
    end
    
  end # Kendrick::Observer
  
  #=============================================================================
  # Note: This module allows for notifications to be sent to observers.
  #=============================================================================
  module Observable

    def create_observer(&method)
      return Observer.new(&method)
    end
    
    #---------------------------------------------------------------------------
    # Provide a method, lambda, anonymous method, proc, or callback.
    #---------------------------------------------------------------------------
    def subscribe(&method)
      @observers ||= []
      # Wrap the target method in an observer.
      observer = create_observer(&method)
      # Collect the created observer.
      @observers << observer
      # Return the created observer. This will allow for unsubscription.
      return observer
    end
    
    #---------------------------------------------------------------------------
    # Stops the observer from listening to notifications.
    #---------------------------------------------------------------------------
    def unsubscribe(observer)
      @observers.delete(observer)
    end
    
    protected
    
    #---------------------------------------------------------------------------
    # Sends notifications to all registered observers.
    #---------------------------------------------------------------------------
    def notify(*args, &block)
      return notify_all(@observers, *args, &block)
    end
    
    #---------------------------------------------------------------------------
    # Iterates through each observer to invoke #notify_observer.
    #---------------------------------------------------------------------------
    def notify_all(observers, *args, &block)
      return @observers.all? { |observer|
        notify_observer(observer, *args, &block)
      }
    end
      
    #---------------------------------------------------------------------------
    # Invokes the observer with an optional callback that can be overloaded.
    #---------------------------------------------------------------------------
    def notify_observer(observer, *args, &block)
      return observer.call(*args, &block)
    end
      
  end # Kendrick::Observable

end # Kendrick

#===============================================================================
# ::Game_BaseItem
#===============================================================================
class ::Game_BaseItem
  
  def id # Simplifies accessibility
    return @item_id # This field doesn't have a public accessor.
  end
  
end # ::Game_BaseItem

#===============================================================================
# ::Game_Battler
#===============================================================================
class ::Game_Battler
  
  #-----------------------------------------------------------------------------
  # Determines if #current_action returns an ::RPG::Item instance.
  #-----------------------------------------------------------------------------
  def item?
    return current_action._?(:item)._?(:is_a?, ::RPG::Item)
  end
  
  #-----------------------------------------------------------------------------
  # Determines if #current_action returns an ::RPG::Skill instance.
  #-----------------------------------------------------------------------------
  def skill? 
    return current_action._?(:item)._?(:is_a?, ::RPG::Skill)
  end
  
  #-----------------------------------------------------------------------------
  # Obtains the last used skill.
  #-----------------------------------------------------------------------------
  def skill
    result = skill? ? current_action.item : last_skill
    return $data_skills[result.id]
  end
  
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
      return Kendrick::Core.load_data(path, result)
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
  def self.try_method(context, method, *args, &block)
    result = false
    condition = context.respond_to?(method)
    if condition
      result = context.send(method, *args)
      block.call(result) unless block.nil?
    end
    return condition
  end

  #-----------------------------------------------------------------------------
  # Evaluates text and returns the expression as a lambda.
  #-----------------------------------------------------------------------------
  def self.eval_method(text, *args)
    args ||= []
    parameters = args.join(", ")
    method = "->(#{parameters}){#{text}}"
    return eval(method)
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
    func = method(symbol)
    return func.to_callee(hash, &callback)
  end

  #-----------------------------------------------------------------------------
  # Allows for safe navigation.  Simplifies null coalescing index expressions.
  #-----------------------------------------------------------------------------
  def maybe(*args, &block)
    condition = is_a?(::NilClass) || !respond_to?(args.first)
    return condition ? nil : send(*args, &block)
  end
  alias :_? :maybe

  #-----------------------------------------------------------------------------
  # Invokes ::Kernal#try_method with the caller provided as the current context.
  #-----------------------------------------------------------------------------
  def try_method(method, *args, &block)
    return ::Kernal.try_method(self, method, *args, &block)
  end
  
  #-----------------------------------------------------------------------------
  # Invokes ::Boolean#convert with the caller provided as the current context.
  #-----------------------------------------------------------------------------
  def to_b
    return ::Boolean.convert(self)
  end
  
  #-----------------------------------------------------------------------------
  # Simplifies multiple assignment operations as explicit block expressions.
  #-----------------------------------------------------------------------------
  def as
    return yield self
  end

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
    callback = ::Callback.new(hash, &options)
    @callbacks << callback
    return callback
  end
  
  #-----------------------------------------------------------------------------
  # Invokes a target method with exception handling provided by an options hash.
  #-----------------------------------------------------------------------------
  def call(*args, &block)
    status = :not_modified
    if @callbacks.all? { |x| x.before(*args) }
    
      begin
        result = super(*args, &block)
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
    options = Options.new(hash)
    block.call(options) unless block.nil?
    return options
  end
  
  def initialize(hash = {}, &block)
    @options = Callback.options(hash, &block)
  end
    
  def before(*args)
    return @options.before.call(*args)
  end
  
  def error(*args)
    return @options.error.call(*args)
  end
  
  def success(*args, &block)
    return @options.success.call(*args)
  end

  def complete(*args, &block)
    return @options.complete.call(*args)
  end    
  
end # ::Callback

#===============================================================================
# Provides a common idiom for callback structures.
#===============================================================================
class ::Callback::Options
  
  def self.before(*args)
    return true
  end
  
  def self.error(error, type)
    raise error
  end
  
  def self.success(data = nil)
    return data
  end
  
  def self.complete(status)
    return status
  end
  
  Hash = {
    :before => method(:before),
    :error => method(:error),
    :success => method(:success),
    :complete => method(:complete)
  }
  
  def initialize(options = {})
    options = ::Callback::Options::Hash.merge(options || {})
    @before = options[:before]
    @error = options[:error]
    @success = options[:success]
    @complete = options[:complete]
  end
  
  def before(&before)
    @before = before unless before.nil?
    return @before
  end
  
  def error(&error)
    @error = error unless error.nil?
    return @error
  end
  
  def success(&success)
    @success = success unless success.nil?
    return @success
  end
  
  def complete(&complete)
    @complete = complete unless complete.nil?
    return @complete
  end
  
end

module Function

  def to_callee(hash={}, &options)
    callee = ::Callee.new(&self)
    callee.subscribe(hash, &options)
    return callee
  end

end

Method.send(:include, Function)
Proc.send(:include, Function)

class Symbol
  
  def to_callee(hash = {}, &options)
    proc = to_proc
    return proc.to_callee(hash, &options)
  end
  
end

#===============================================================================
# This module just makes handling and parsing booleans much easier.
#===============================================================================
module ::Boolean
  @@true_strings = ["true", "t", "1"] # can append "yes"
  @@false_strings = ["false", "f", "0"] # can append "no"
  
  #-----------------------------------------------------------------------------
  # Attempts a custom, overloadable, conversion of objects to ::Boolean.
  #-----------------------------------------------------------------------------
  def self.convert(object)
    return case object
      when ::Numeric
        object != 0
      when ::String
        downcase = object.downcase
        false if @@false_strings.include?(downcase) 
        true if @@true_strings.include?(downcase)
      else 
        !!object
    end #case
  end #self.convert
      
end # ::Boolean

TrueClass.send(:include, ::Boolean)
FalseClass.send(:include, ::Boolean)

#===============================================================================
# This global method returns evaluated text as an anonymous Proc.
#===============================================================================
def eval_method(text, *args)
  return ::Kernal.eval_method(text, *args)
end
