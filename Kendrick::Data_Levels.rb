=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Data Levels
Version:    v0.9.3

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels"] = "v0.9.3"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick::require("Kendrick::Core" => "v0.9.2+")

#===============================================================================
# Note: This module will contain all new data structures for the Data Levels 
# script.
#===============================================================================
module Kendrick::Data_Levels
  #=============================================================================
  # Note: This area defines the vocab for Kendrick:: Data Levels
  #=============================================================================
  LevelName         = "LV."       # The name provided to message boxes.
  LevelFormat       = "%s %s%d"   # The format of the data's name
  Default_Max_Level = 3           # The maximum level for any datum.
  Level_Enabled     = true        # Default enabled flag for all data.
    
  #=============================================================================
  # Note: This structure is used to set immutable data for the data levels.
  #=============================================================================
  module Level_Provider      
    attr_reader   :max_lv         # Stores the level cap.
             
    #---------------------------------------------------------------------------
    # The setup method - alias with :initialize on custom classes.
    #---------------------------------------------------------------------------
    def load_level_provider(max_lv = Default_Max_Level, 
      enable_progress = Level_Enabled)
      @max_lv = max_lv
      @level_enabled = enable_progress
    end
    
    #---------------------------------------------------------------------------
    # Idiomatic accessor for @level_enabled.
    #---------------------------------------------------------------------------
    def level_enabled?; @level_enabled; end
    
  end # Kendrick::Data_Levels::Level_Provider
  
  #=============================================================================
  # Note: This structure is used to store and manipulate level data about an
  # associated piece of data.
  #=============================================================================
  module Level_Management
    include ::Kendrick::Observable
    
    attr_reader :lv     # The current level
    attr_reader :name   # The original provided name
    attr_reader :max_lv # Expose for Detemer.
    
    #---------------------------------------------------------------------------
    # The setup method - alias with :initialize on custom classes.
    #---------------------------------------------------------------------------
    def level_management_setup(data = self, id = self.id, 
      name = self.name, level = 1)
      @data = data
      @id = id
      @max_lv = data.max_lv
      @name = name      # The unaugmented name for display.
      self.lv = level   # Only call after @max_lv has been set.
    end
      
    def level_enabled?; @data.level_enabled?; end
    def level_up?;      @lv != @max_lv;       end
    def level_down?;    @lv != 1;             end

    def level_up;       set_level(@lv + 1); end
    def level_down;     set_level(@lv - 1); end
    def ratio;          @lv / @max_lv.to_f; end
        
    def display_name
      lv_name = ::Kendrick::Data_Levels::LevelName
      format = ::Kendrick::Data_Levels::LevelFormat
      sprintf(format, @name, lv_name, @lv)
    end
    
    #---------------------------------------------------------------------------
    # This will send notifications.
    #---------------------------------------------------------------------------
    def set_level(level)
      self.lv = level if @lv != level
    end
    
    protected
    def lv=(level)
      @lv = [[level, @max_lv].min, 1].max
      notify(:level, level)
    end
    
  end # Kendrick::Data_Levels::Level_Management
  
  #=============================================================================
  # Note: This module provides a simple mixin to create relations between an
  # object that can be leveled and an object that consumes the levels.
  #=============================================================================
  module Level_Ownership
    include ::Kendrick::Core
    include ::Kendrick::Observable
    include ::Enumerable
          
    def [](data_id); @learned[data_id]; end
    def each(&block); @learned.each(&block); end
              
    #---------------------------------------------------------------------------
    # The setup method - alias with :initialize on custom classes.
    #---------------------------------------------------------------------------
    def level_ownership_setup(options = {})
      # Set missing_index default with #load_datum.
      @learned = Hash.new(&method(:load_datum))
      @options = options
    end
              
    protected
    
    #---------------------------------------------------------------------------
    # Abstract: override in derived classes for new instance defaults.
    #---------------------------------------------------------------------------
    def data(data_id); raise error(:missing_method); end
    
    #---------------------------------------------------------------------------
    # Virtual: allow overriding. Defaults all levels to 1.
    #---------------------------------------------------------------------------
    def providers; @providers ||= Hash.new { |h, k| h[k] = 1 }; end
        
    #---------------------------------------------------------------------------
    # Virtual: allow overriding.
    #---------------------------------------------------------------------------
    def create_manager(data, lv=1)
      Level_Manager.new(data, data.id, data.name, lv)
    end
    
    private
    
    #---------------------------------------------------------------------------
    # Used to simplify navigation of options and class methods.
    #---------------------------------------------------------------------------
    def option(symbol); @options[symbol] || method(symbol); end
    
    #---------------------------------------------------------------------------
    # Creates a new manager if the indexed manager is currently not found.
    #---------------------------------------------------------------------------
    def load_datum(learned, data_id)
      create_datum(data_id) unless @learned.has_key?(data_id)
    end

    def create_datum(data_id)
      data = option(:data).call(data_id)
      providers = option(:providers).call
      level = providers[data_id]
      manager = create_manager(data, level)
      manager.subscribe { |attr, value| 
        notify(manager, attr, value, data_id) 
      }
      # Don't call @learned[data_id] = manager.  It will invoke #load_datum.
      @learned.store(data_id, manager)    
    end
    
  end # Kendrick::Data_Levels::Level_Ownership
  
  class Level_Owner
    include Level_Ownership
    alias :initialize :level_ownership_setup
  end # Kendrick::Data_Levels::Level_Owner
  
  class Level_Manager
    include Kendrick::Data_Levels::Level_Management
    alias :initialize :level_management_setup
  end # Kendrick::Data_Levels::Level_Manager
  
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
