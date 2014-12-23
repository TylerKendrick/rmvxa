=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Rpg Maker Presentation Foundation
Version:    v0.0.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::RMPF"] = "v0.0.1"
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
  
  class Style;      end
  class Control;    end
end # ::Kendrick::RMPF
