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
  class Binding;    end
  class Style;      end
  class Control;    end
end
