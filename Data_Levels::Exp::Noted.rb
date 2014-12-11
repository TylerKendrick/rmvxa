=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Data Levels - Experience - Noted
Version:    v0.9.1
Git:        https://github.com/TylerKendrick/rmvxace_data_levels

Language:   RGSS3
Framework:  RPG Maker VX Ace
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Exp::Noted"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick.require("Kendrick::Data_Levels::Exp" => "v0.9.1")

#===============================================================================
# Note: This class contains the core logic for Kendrick scripts.
#===============================================================================
module Kendrick::Data_Levels::Exp::Noted
  #-----------------------------------------------------------------------------
  # Change values in Level_Filter_Map to change the name of the tags.
  #-----------------------------------------------------------------------------
  Filter_Map = {
    :base_exp => :base_exp,
    :exp_gain => :exp_gain,
    :exp_formula => :exp_formula,
    :exp_progress => :exp_progress
  }
  
  #-----------------------------------------------------------------------------
  # Register filters for noted parsing.
  #-----------------------------------------------------------------------------
  ::Kendrick::Noted.Filters [ 
    Filter_Map[:base_exp], 
    Filter_Map[:exp_gain], 
    Filter_Map[:exp_formula], 
    Filter_Map[:exp_progress]
  ]  

  #===========================================================================
  # Note: This module enables setup data to be provided via notes for data
  # that maintains experience points.
  #===========================================================================
  module Level_Provider
    include ::Kendrick::Noted
    include ::Kendrick::Data_Levels::Exp::Level_Provider
    
    alias :noted_experience_provider_load_level_provider :load_level_provider
    #---------------------------------------------------------------------------
    # This is the main setup method.  Can alias with :initialize.
    #---------------------------------------------------------------------------
    def load_level_provider
      noted_experience_provider_load_level_provider
      load_notes
    end
    
    alias :parse_experience_tag :parse_tag
    #---------------------------------------------------------------------------
    # This is the main setup method.  Can alias with :initialize.
    #---------------------------------------------------------------------------
    def parse_tag(tag) # Required by Kendrick::Core::Noted
      parse_experience_tag(tag)
      case tag.name
      when Filter_Map[:base_exp]
        @base_exp = tag.value.to_i
      when Filter_Map[:exp_gain]
        @exp_gain = tag.value.to_i
      when Filter_Map[:exp_formula]
        @exp_formula = eval_method(tag.value, "s", "lv")
      when Filter_Map[:exp_progress]
        @exp_progress = tag.value == "true"
      end
    end
    
  end # Kendrick::Data_Levels::Exp::Noted::Level_Provider
  
end # Kendrick::Data_Levels::Exp::Noted
