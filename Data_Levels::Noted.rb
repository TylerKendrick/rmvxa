=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Data Levels - Noted
Version:    v0.9.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Noted"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick::require(
  "Kendrick::Noted" => "v0.9.1",
  "Kendrick::Data_Levels" => "v0.9.1")

#===============================================================================
# Note: This module contains predefined tags to search in note sections and 
# provide as a framework extension to Kendrick::Data_Levels.
#===============================================================================
module Kendrick::Data_Levels::Noted
  
  #-----------------------------------------------------------------------------
  # Change values in Level_Filter_Map to change the name of the tags.
  #-----------------------------------------------------------------------------
  Filter_Map = {
    :level => :level,
    :max_level => :max_level,
    :level_progress => :level_progress
  }
  
  #-----------------------------------------------------------------------------
  # Register filters for noted parsing.
  #-----------------------------------------------------------------------------
  ::Kendrick::Noted.Filters [ 
    Filter_Map[:level], 
    Filter_Map[:max_level], 
    Filter_Map[:level_progress] 
  ]
  
  #=============================================================================
  # Note: This module searches a provider for tags registered to Data_Levels.
  #=============================================================================
  module Level_Provider
    include Kendrick::Data_Levels::Level_Provider
    include Kendrick::Noted
    
    alias :noted_load_level_provider :load_level_provider
    def load_level_provider
      noted_load_level_provider
      load_notes
    end
    
    #---------------------------------------------------------------------------
    # Required by Kendrick::Core::Noted
    #---------------------------------------------------------------------------
    def parse_tag(tag)
      case tag.name
      when Filter_Map [:max_level]
        @max_lv = tag.value.to_i
      when Filter_Map [:level_progress]
        attr = tag["enabled"]
        value = attr ? attr.value : tag.innerText
        @enable_progress = value != "false"
      end
    end
    
  end # Kendrick::Data_Levels::Noted::Level_Provider
  
end # Kendrick::Data_Levels::Noted
