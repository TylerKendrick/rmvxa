=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Data Levels - Host
Version:    v0.9.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Host"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick.require("Kendrick::Data_Levels" => "v0.9.1")

#===============================================================================
# Note: Provides objects to simplify creation of host data levels.
#===============================================================================
module Kendrick::Data_Levels::Host

    #===========================================================================
    # Note: Creates a composite manager/provider for self hosted providers.
    #===========================================================================
    module Level_Management
      include Kendrick::Data_Levels::Level_Provider
      include Kendrick::Data_Levels::Level_Management
      
      alias :hosted_level_management_setup :level_management_setup
      def level_management_setup
        load_level_provider
        hosted_level_management_setup
      end
      
    end #Kendrick::Data_Levels::Host::Level_Management
    
end # Kendrick::Data_Levels
