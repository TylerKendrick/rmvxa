=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Data Levels - Host - Noted
Version:    v0.9.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Host::Noted"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick.require(
  "Kendrick::Data_Levels::Host" => "v0.9.1"
  "Kendrick::Noted" => "v0.9.1",
)
#===============================================================================
# This module simplifies self-hosted level provider creation.
#===============================================================================
module Kendrick::Data_Levels::Host::Noted
    
  #=============================================================================
  # Note: Creates a composite manager/provider that reads notes.
  #=============================================================================
  module Level_Management
    include Kendrick::Data_Levels::Level_Management
    include Kendrick::Data_Levels::Noted::Level_Provider
    
    alias :noted_hosted_level_provider_level_management_setup :level_management_setup
    def level_management_setup
      load_level_provider
      noted_hosted_level_provider_level_management_setup
    end
    
  end # Kendrick::Data_Levels::Host::Noted::Level_Management
      
end # Kendrick::Data_Levels

#===============================================================================
# Note: This override exists to provide the call scripts for invocation in 
# events and the editor.
#===============================================================================
class ::Game_Interpreter
  
  def set_level_progress(progress_data, level)
    progress_data.set_level(level)
  end

end # ::Game_Interpreter
