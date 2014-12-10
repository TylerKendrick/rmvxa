=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Core
Version:    v0.9.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Core"] = "v0.9.1"
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
          when :exact_vesion
            message = "missing script: #{name} + #{value}"
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
      resolve_dependencies { |name, value, errorNo|
        raise ::Kendrick::Errors[:missing_script].call(name, value, errorNo)
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
      @@scripts.each { |pair|
        key, values = pair
        values.each { |value|
          resolve_dependency(key, value, &on_error)
        }
      }
    end
    
    #---------------------------------------------------------------------------
    # Determines how to handle individual dependencies
    #---------------------------------------------------------------------------
    def self.resolve_dependency(name, value, &on_error)
      on_error.call(name, value) if !$imported.has_key?(name) && on_error
    end
    
  end # Kendrick::Core
  
  #=============================================================================
  # Note: This class simply wraps a method for unsubscription from observables.
  #=============================================================================
  class Observer
    
    def initialize(method)
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

    #---------------------------------------------------------------------------
    # Provide a method, lambda, anonymous method, proc, or callback.
    #---------------------------------------------------------------------------
    def subscribe(method)
      @observers ||= []
      # Wrap the target method in an observer.
      observer = Observer.new(method)
      # Collect the created observer.
      @observers << observer
      # Return the created observer. This will allow for unsubscription.
      observer
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
    def notify(options = {}, *args, &block)
      options = ::Callback::Options.merge(options || {})
      notify_all(@observers, options, *args, &block)
    end
    
    #---------------------------------------------------------------------------
    # Iterates through each observer to invoke #notify_observer.
    #---------------------------------------------------------------------------
    def notify_all(observers, options = {}, *args, &block)
      options = ::Callback::Options.merge(options || {})
      @observers.each { |observer|
        notify_observer(observer, options, *args, &block)
      }
    end
      
    #---------------------------------------------------------------------------
    # Invokes the observer with an optional callback that can be overloaded.
    #---------------------------------------------------------------------------
    def notify_observer(observer, options = {}, *args, &block)
      options = ::Callback::Options.merge(options || {})
      callee = observer.callee(:call)
      callback = callee.callback(options)
      callee.call(*args, &block)
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
      callee = callee(:kendrick_load_database)
      callee.callback(
        :before => Kendrick::Core.method(:preload_database),
        :error => ->(e, type) { raise e },
        :complete => ->(status) { Kendrick::Core.load_database })
      callee.call
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
    
  end
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
  def callee(symbol)
    method = method(symbol)
    return Callee.new(method)
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
class ::Callee < ::Observer
  
  #-----------------------------------------------------------------------------
  # Creates and registers a new callback for the target method.
  #-----------------------------------------------------------------------------
  def callback(options = {})
    options = ::Callback::Options.merge(options)

    @callbacks ||= []
    callback = ::Callback.new(options)
    @callbacks << callback
    return callback
  end
  
  #-----------------------------------------------------------------------------
  # Invokes a target method with exception handling provided by an options hash.
  #-----------------------------------------------------------------------------
  def call(*args, &block)
    status = :not_modified
    # Nifty idiom used to obtain value as boolean.
    return unless !!callbacks(:before)
    
    begin
      result = @method.call(*args)
      callbacks(:success, result)
      status = :success
    rescue Exception => e
      callbacks(:error, e, :error)
      status = :error
    end
    
    callbacks(:complete, status)
  end
  
  private 
  
  def callbacks(method, *args)
    @callbacks.each { |x| x.call(method, *args) }
  end
  
end # ::Callee

#===============================================================================
# ::Callee
#===============================================================================
class Callback

  #-----------------------------------------------------------------------------
  # Provides a common idiom for callback structures.
  #-----------------------------------------------------------------------------
  def self.options(before = ->{}, error = ->(e, type){},
    success = ->(data = nil){}, complete = ->(status){})
    return {
      :before => before,
      :error => error,
      :success => success,
      :complete => complete
    }
  end
  
  Options = ::Callback.options
  
  def initialize(options = {})
    @callback_idiom = ::Callback::Options.merge(options)
  end
  
  def call(method, *args)
    @callback_idiom[method].call(*args)
  end
  
end :: Callback

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
    
    case object
      when ::Numeric
        return object != 0
      when ::String
        downcase = object.downcase
        return false if @@false_strings.include?(downcase) 
        return true if @@true_strings.include?(downcase)
    end
    
    return nil
  end
      
end # ::Boolean

class ::TrueClass
  include ::Boolean
end # ::TrueClass

class ::FalseClass
  include ::Boolean
end # ::FalseClass

#===============================================================================
# This global method returns evaluated text as an anonymous Proc.
#===============================================================================
def eval_method(text, *args)
  return ::Kernal.eval_method(text, *args)
end
