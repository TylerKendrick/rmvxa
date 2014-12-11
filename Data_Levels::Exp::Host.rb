=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Data Levels - Experience - Host
Version:    v0.9.1
Git:        https://github.com/TylerKendrick/rmvxace_data_levels

Language:   RGSS3
Framework:  RPG Maker VX Ace
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Exp::Host"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick.require("Kendrick::Data_Levels::Exp" => "v0.9.1")

#===============================================================================
# Note: Provides objects to simplify creation of host data levels.
#===============================================================================
module Kendrick::Data_Levels::Exp::Host

  #=============================================================================
  # Note: Creates a composite manager/provider for self hosted providers.
  #=============================================================================
  module Level_Management
    include Kendrick::Data_Levels::Exp::Level_Management
    include Kendrick::Data_Levels::Exp::Level_Provider
    
    alias :hosted_load_level_provider :load_level_provider
    #---------------------------------------------------------------------------
    # This is the main setup method.  Can alias with :initialize.
    #---------------------------------------------------------------------------
    def level_provider_setup
      hosted_load_level_provider
      level_management_setup
    end
    
  end #Kendrick::Data_Levels::Host::Level_Management

end # Kendrick::Data_Levels::Exp::Host
