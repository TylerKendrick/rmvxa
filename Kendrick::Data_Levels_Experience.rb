=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Data Levels - Experience
Version:    v1.0.0
Git:        https://github.com/TylerKendrick/rmvxace_data_levels

Language:   RGSS3
Framework:  RPG Maker VX Ace
Requires:   Data Levels v1
--------------------------------------------------------------------------------
LICENSE: 

The MIT License (MIT)

Copyright (c) 2014 Tyler Kendrick

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--------------------------------------------------------------------------------
Description:

The following script enables the ability to gain experience for leveling game 
data.  This is an addon to the "Data Levels" script.

--------------------------------------------------------------------------------
Setup:

This script must be placed under the "Data_Levels" script.

No effective implementations are provided.  It is up to the discretion of the
consumer of this product to provide useful implementation.

#===============================================================================
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Experience"] = true
#===============================================================================
# Note: This class contains the core logic for Kendrick scripts.
#===============================================================================
module Kendrick
  #=============================================================================
  # Note: Need to register objects for core script setup.
  #=============================================================================
  Noted.Tags [ :base_exp, :exp_gain, :exp_formula ]
  Script.Dependencies ["Kendrick::Data_Levels"]
  
  #=============================================================================
  # Note: This area is used for customizations to progression formulae.  It also
  # acts as a namespace for all Kendrick scripts
  #=============================================================================
  module Data_Levels
    # The multiplier used in formula.
    Default_Base_Exp = 5                            
    # The exp gain per use.
    Default_Exp_Gain  = 1                           
    # The formula for level requirements.
    Default_Exp_Formula = "s.base_exp ** (lv-1) - 1"

    module Level_Provider
      attr_reader :base_exp     # The starting exp passed to the exp formula
      attr_reader :exp_gain     # The base exp to be rewarded
      attr_reader :exp_formula  # The formula to calculate level exp requirement
        
      def exp_for_level(lv, s = self)
        return eval(@exp_formula)
      end
            
      alias :kendrick_data_levels_experience_provider_setup :level_setup
      def level_setup
        kendrick_data_levels_experience_provider_setup
        @base_exp = Default_Base_Exp
        @exp_gain = Default_Exp_Gain
        @exp_formula = Default_Exp_Formula
      end
    end # Kendrick:Data_Levels::Level_Provider
    #===========================================================================
    # Note: This class contains the bulk of the logic for the skill progression
    # system.  Here, we keep relational data between target data and their
    # correlative properties (i.e. exp., level, etc)
    #===========================================================================
    class Level_Manager < Object
      attr_reader :exp      # The total exp associated with the data
      attr_reader :max_exp  # calculated from the max_lv
      
      alias :kendrick_actor_skill_progression_data_progress_initialize :initialize
      def initialize(owner, data, data_id, name, level = 1)
        kendrick_actor_skill_progression_data_progress_initialize(owner, data, data_id, name, level)
        @exp = @data.exp_for_level(level)
        @max_exp = @data.exp_for_level(@max_lv)
      end
        
      def to_next
        # Don't get exp requirements for levels greater than max.
        next_level = [@lv + 1, @max_lv].min
        return @data.exp_for_level(next_level)
      end

      def to_next? # Determines if exp is greater than next level req.
        return level_up? && @exp >= to_next
      end
          
      def gain_exp(amount = @data.exp_gain) # Use loaded gains as default
        set_exp(@exp + amount) if level_up?
      end
      
      def set_exp(amount)
        @exp = [[amount, 0].max, @max_exp].min
        # If exp gain exceeds multiple level requirements, loop until it doesn't
        level_up while to_next? && level_up?
      end
      
      alias :kendrick_actor_skill_progression_data_progress_set_level :set_level 
      def set_level(level) # Sets both level and exp
        # Invoke setter to clamp to max_level
        kendrick_actor_skill_progression_data_progress_set_level(level)
        @exp = @data.exp_for_level(level) # Match exp to new level
      end
    end # Kendrick::Data_Levels::Level_Manager
  end # Kendrick::Data_Levels
end # Kendrick
#===============================================================================
# Note: This override exists to provide the call scripts for invocation in
# events and the editor.
#===============================================================================
class ::Game_Interpreter
  def set_data_level_experience(progress_data, level)
    progress_data.set_exp(level)
  end
end # Game_Interpreter
