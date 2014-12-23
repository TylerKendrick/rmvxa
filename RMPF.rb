=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Rpg Maker Presentation Foundation
Version:    v0.0.3

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::RMPF"] = "v0.0.3"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick::require("Kendrick::Core" => "v0.9.3")

module Kendrick::RMPF
  class Binding
    include ::Kendrick::Observable
    
    def initialize(context, path = "")
      super
      @context = context
      @path = Path.new(source, path)
      context.subscribe(&on_change)
    end
  
    private
    def on_change(name, old_value, new_value)
      notify(@value, eval(@context)) if path.params[1] == name
    end

    def eval
      @value = @context
      @path.length.times do |i|
        @value = @value.send(path.params[i].to_sym)
      end
      @value
    end
    
    class Path
      attr_accessor :value
      attr_reader   :params
      
      def initialize(path = "")
        @value = path
        @params = path.split('.')
      end
    end # ::Kendrick::RMPF::Binding::Path
  end # ::Kendrick::RMPF::Binding
  
  class Style      
    attr_reader :params
    attr_reader :type
    
    def initialize(type, params = {})
      @type = type
      @params = params
    end
  end # ::Kendrick::RMPF::Style
  
  class Control
    
    def bind(name, binding)
      bindings << binding.subscribe { |old_value, new_value|
        self.send(name.to_s, new_value) if(old_value != new_value)
      }
    end
    
    private 
    def bindings; @bindings ||= []; end
  end # ::Kendrick::RMPF::Control
end # ::Kendrick::RMPF
