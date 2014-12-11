=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Data Levels - Experience
Version:    v0.9.1
Git:        https://github.com/TylerKendrick/rmvxace_data_levels

Language:   RGSS3
Framework:  RPG Maker VX Ace
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Exp"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick::require("Kendrick::Data_Levels" => "v0.9.2")

#===============================================================================
# Note: This class contains the core logic for Kendrick scripts.
#===============================================================================
module Kendrick::Data_Levels::Exp
  # Determines if exp is enabled by default.
  Exp_Enabled         = true
  # The multiplier used in formula.
  Default_Base_Exp    = 5                            
  # The exp gain per use.
  Default_Exp_Gain    = 1                           
  # The formula for level requirements.
  Default_Exp_Formula = "s.base_exp ** (lv-1) - 1"

  #=============================================================================
  # Note: This module extends the level ownership module to create an
  # Experience_Manager instance instead of a Level_Manager instance.
  #=============================================================================
  module Level_Ownership
    include Kendrick::Data_Levels::Level_Ownership
          
    #---------------------------------------------------------------------------
    # Return a Data_Levels::Exp::Level_Manager instance instead of a 
    # Data_Levels::Level_Manager instance.
    #---------------------------------------------------------------------------
    def create_manager(data, lv = 1)
      return Level_Manager.new(data, data.id, data.name, lv)
    end
    
  end # Kendrick::Data_Levels::Exp::Experience_Ownership
    
  #===========================================================================
  # Note: This provider contains the data that represents the values for 
  # initializing level data with exp.
  #===========================================================================
  module Level_Provider
    include Kendrick::Data_Levels::Level_Provider
    
    attr_accessor :exp_enabled  # Determines if exp will progress
    attr_reader   :base_exp     # The starting exp passed to the exp formula
    attr_reader   :exp_gain     # The base exp to be rewarded
    attr_reader   :exp_formula  # The formula to calculate level exp requirement
      
    #---------------------------------------------------------------------------
    # Invokes an evaluated lambda to invoke the formula.
    #---------------------------------------------------------------------------
    def exp_for_level(lv, s = self)
      return @exp_formula.call(lv, s)
    end
       
    alias :exp_load_level_provider :load_level_provider
    #---------------------------------------------------------------------------
    # This is the main setup method.  Can alias with :initialize.
    #---------------------------------------------------------------------------
    def load_level_provider(max_lv = Kendrick::Data_Levels::Default_Max_Level,
      level_enabled = Kendrick::Data_Levels::Level_Enabled,
      exp_enabled = Kendrick::Data_Levels::Exp::Exp_Enabled)
      # Ensure you pass parameters to alias!
      exp_load_level_provider(max_lv, level_enabled)
      @base_exp = Default_Base_Exp
      @exp_gain = Default_Exp_Gain
      @exp_formula = eval_method(Default_Exp_Formula, "lv", "s")
      @exp_enabled = exp_enabled
    end
          
    #---------------------------------------------------------------------------
    # Idiomatic accessor for @exp_enabled.
    #---------------------------------------------------------------------------
    def exp_enabled?
      return @exp_enabled
    end
    
  end # Kendrick:Data_Levels::Exp::Experience_Provider
  
  #===========================================================================
  # Note: This class contains the bulk of the logic for the exp progression
  # system.
  #===========================================================================
  module Level_Management
    include ::Kendrick::Data_Levels::Level_Management
    
    attr_reader :exp      # The total exp associated with the data
    attr_reader :max_exp  # calculated from the max_lv
    
    alias :kendrick_experience_management_setup :level_management_setup
    #---------------------------------------------------------------------------
    # This is the main setup method.  Can alias with :initialize
    #---------------------------------------------------------------------------
    def level_management_setup(data, data_id, name, level = 1)
      kendrick_experience_management_setup(data, data_id, name, level)
      @exp = @data.exp_for_level(level)
      @max_exp = @data.exp_for_level(@max_lv)
    end
      
    #---------------------------------------------------------------------------
    # Determines the amount of exp for the next level (up until max lv).
    #---------------------------------------------------------------------------
    def to_next
      # Don't get exp requirements for levels greater than max.
      next_level = [lv + 1, @max_lv].min
      return @data.exp_for_level(next_level)
    end

    #---------------------------------------------------------------------------
    # Determines if exp is greater than next level req.
    #---------------------------------------------------------------------------
    def to_next? 
      return level_up? && @exp >= to_next
    end
        
    #---------------------------------------------------------------------------
    # Increments exp by the default gain amount.
    #---------------------------------------------------------------------------
    def gain_exp(amount = @data.exp_gain) # Use loaded gains as default
      set_exp(@exp + amount) if level_up?
    end
    
    #---------------------------------------------------------------------------
    # Explicitly sets the exp amount and invokes level_up until satisfied.
    #---------------------------------------------------------------------------
    def set_exp(amount)
      @exp = [[amount, 0].max, @max_exp].min
      # If exp gain exceeds multiple level requirements, loop until it doesn't
      level_up while to_next? && level_up?
    end
    
    #---------------------------------------------------------------------------
    # Defer to the Law of Demeter for why I did this.
    #---------------------------------------------------------------------------
    def exp_enabled?
      return @data.exp_enabled?
    end
    
    alias :kendrick_actor_skill_progression_data_progress_set_level :set_level 
    #---------------------------------------------------------------------------
    # Makes sure to set the exp when the level is changed.
    #---------------------------------------------------------------------------
    def set_level(level) # Sets both level and exp
      # Invoke setter to clamp to max_level
      kendrick_actor_skill_progression_data_progress_set_level(level)
      @exp = @data.exp_for_level(level) # Match exp to new level
    end
    
  end # Kendrick::Data_Levels::Exp::Level_Management

  class Level_Owner < ::Kendrick::Data_Levels::Level_Owner
    include ::Kendrick::Data_Levels::Exp::Level_Ownership
    alias :initialize :level_ownership_setup
  end #Kendrick::Data_Levels::Experience_Owner
  
  class Level_Manager < ::Kendrick::Data_Levels::Level_Manager
    include Kendrick::Data_Levels::Exp::Level_Management
    alias :initialize :level_management_setup
  end # Kendrick::Data_Levels::Exp::Level_Manager  

end # Kendrick::Data_Levels::Exp

#===============================================================================
# Note: This override exists to provide the call scripts for invocation in
# events and the editor.
#===============================================================================
class ::Game_Interpreter
  
  def set_data_level_experience(progress_data, level)
    progress_data.set_exp(level)
  end
  
end # Game_Interpreter
