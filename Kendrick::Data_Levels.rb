=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Data Levels
Version:    v0.9.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Data_Levels"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick::require("Kendrick::Core" => "v0.9.1")

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
    def level_enabled?
      return @level_enabled
    end
    
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
      
    #---------------------------------------------------------------------------
    # Appease Demeter.
    #---------------------------------------------------------------------------
    def level_enabled?
      return @data.level_enabled?
    end
    
    #---------------------------------------------------------------------------
    # Use this for scaling in formulae.
    #---------------------------------------------------------------------------
    def ratio
      # Remember to convert to_f, otherwise will return either 0 or 1.
      @lv / @max_lv.to_f
    end
    
    #---------------------------------------------------------------------------
    # This will actually perform a levelup and send notifications.
    #---------------------------------------------------------------------------
    def level_up # Invoke setter to set with clamped value
      set_level(@lv + 1)
    end
           
    #---------------------------------------------------------------------------
    # Idiomatic accessor to determine if level_up can be performed.
    #---------------------------------------------------------------------------
    def level_up? # Determines if level_up can be invoked
      return @lv != @max_lv
    end
        
    #---------------------------------------------------------------------------
    # This can be used in windows to display the level along with the name.
    #---------------------------------------------------------------------------
    def display_name
      name = ::Kendrick::Data_Levels::LevelName
      format = ::Kendrick::Data_Levels::LevelFormat
      return sprintf(format, @name, name, @lv)
    end
    
    #---------------------------------------------------------------------------
    # This will actually perform a levelup and send notifications.
    #---------------------------------------------------------------------------
    def set_level(level)
      # Obtain private setter for clamping value.
      callee = callee(:lv=)
      # Create a callback
      callback = callee.callback(
        # Determine if setter should execute.
        :before => -> { @lv != level },
        # Notify when complete.
        :complete => ->(state) { notify(nil, :level, level) }
      )
      # Invoke the setter with callbacks and notifications
      callee.call(level)
    end
    
    private
    #---------------------------------------------------------------------------
    # This will clamp the level to its provided maximum value.
    #---------------------------------------------------------------------------
    def lv=(level)
      @lv = [[level, @max_lv].min, 1].max
    end
    
  end # Kendrick::Data_Levels::Level_Management
  
  #=============================================================================
  # Note: This module provides a simple mixin to create relations between an
  # object that can be leveled and an object that consumes the levels.
  #=============================================================================
  module Level_Ownership
    include ::Kendrick::Core
          
    #---------------------------------------------------------------------------
    # Simplifies accessibility.  Strictly for simplicity.
    #---------------------------------------------------------------------------
    def [](data_id)
      return @learned[data_id]
    end
              
    #---------------------------------------------------------------------------
    # The setup method - alias with :initialize on custom classes.
    #---------------------------------------------------------------------------
    def level_ownership_setup(options = {})
      # Set missing_index default with #load_datum.
      @learned = Hash.new(&method(:load_datum))
      @options = options
    end
        
    #---------------------------------------------------------------------------
    # Allow overriding, but take default from option.
    #---------------------------------------------------------------------------
    def display_level_up?(data_id)
      return option(:display_message)
    end
              
    protected
    
    #---------------------------------------------------------------------------
    # Allow overriding.
    #---------------------------------------------------------------------------
    def on_notify(attr, value, data_id)
      case attr
        when :level
          on_notify_level(data_id) if display_level_up?(data_id)
      end
    end
    
    #---------------------------------------------------------------------------
    # Display the message in a game window on notify.
    #---------------------------------------------------------------------------
    def on_notify_level(data_id)
      name, lv = @learned[data_id].as { |x| x.name, x.lv }
      $game_message.new_page
      lv_name = ::Kendrick::Data_Levels::LevelName
      message = sprintf(::Vocab::LevelUp, name, lv_name, level)
      $game_message.add(message)
    end    
    
    #---------------------------------------------------------------------------
    # Abstract: override in derived classes for new instance defaults.
    #---------------------------------------------------------------------------
    def data(data_id)
      raise error(:missing_method)
    end
    
    #---------------------------------------------------------------------------
    # Abstract: override in derived classes for new instance defaults.
    #---------------------------------------------------------------------------
    def providers
      raise error(:missing_method)
    end
        
    #---------------------------------------------------------------------------
    # Virtual: allow overriding.
    #---------------------------------------------------------------------------
    def create_manager(data, lv=1)
      return Level_Manager.new(data, data.id, data.name, lv)
    end
    
    private
    
    #---------------------------------------------------------------------------
    # Used to simplify navigation of options and class methods.
    #---------------------------------------------------------------------------
    def option(symbol)
      return @options[symbol] || method(symbol)
    end
    
    #---------------------------------------------------------------------------
    # Creates a new manager if the indexed manager is currently not found.
    #---------------------------------------------------------------------------
    def load_datum(learned, data_id)
      @source ||= option(:providers).call
      @providers ||= ::Hash[@source]
          
      create_datum(data_id) unless @learned.has_key?(data_id)
    end
    
    #---------------------------------------------------------------------------
    # Creates a new manager.
    #---------------------------------------------------------------------------
    def create_datum(data_id)
      data = option(:data).call(data_id)
      level = @providers[data_id] || 1
      manager = create_manager(data, level)
      manager.subscribe(->(attr, value) { 
        on_notify(attr, value, data_id) 
      })
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
