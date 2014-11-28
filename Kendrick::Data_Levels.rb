=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Data Levels
Version:    v1.0.0

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
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

The following core script enables a way to maintain level progression data for 
a variety of game objects.

--------------------------------------------------------------------------------
Setup:

No effective implementations are provided.  It is up to the discretion of the
consumer of this product to provide useful implementation.

#===============================================================================
=end
$imported ||= {}
$imported["Kendrick::Data_Levels"] = true
#===============================================================================
# Note: This area defines the default namespace for Kendrick scripts.
#===============================================================================
module Kendrick  
  #=============================================================================
  # Note: Need to register objects for core script setup.
  #=============================================================================
  Noted.Tags [ :level, :max_level, :progress ]
  Script.Dependencies ["Kendrick::Core"]
  
  #=============================================================================
  # Note: This module will contain all new data structures for the Data Levels 
  # script.
  #=============================================================================
  module Data_Levels
    Display_Format = "%s lv.%d"         # The format of the data's name
    Default_Max_Level = 3               # The maximum level for any datum.
        
    #===========================================================================
    # Note: This structure is used to set immutable data for the data levels.
    #===========================================================================
    module Level_Provider      
      attr_reader :enable_progress
      attr_reader :max_lv
               
      def level_setup(max_lv = Default_Max_Level, enable_progress = true)
        @max_lv = max_lv
        @enable_progress = enable_progress
      end
    end # Kendrick::Data_Levels::Level_Provider
    #===========================================================================
    # Note: This structure is used to store and manipulate level data about an
    # associated piece of data.
    #===========================================================================
    class Level_Manager < Object
      attr_reader :lv     # The current level
      
      def initialize(owner, data, id, name, level = 1)
        super
        @owner = owner
        @data = data
        @id = id
        @max_lv = data.max_lv
        @name = name      # The unaugmented name for display.
        self.lv = level   # Only call after @max has been set.
      end
        
      def level_up # Invoke setter to set with clamped value
        set_level(@lv + 1)
      end
             
      def level_up? # Determines if level_up can be invoked
        return @lv != @max_lv
      end
      
      def name # Used for display when level_up is invoked.
        return sprintf(Display_Format, @name, @lv)
      end
      
      def set_level(level)
        if @lv != level
          self.lv = level
          @owner.display_level_up(@id) if @owner.display_level_up?(@id)
        end
      end
      
      private
      def lv=(level)
        @lv = [[level, @max_lv].min, 1].max
      end
    end # Kendrick::Data_Levels::Level_Manager
    #===========================================================================
    # Note: This module provides a simple mixin to create relations between an
    # object that can be leveled and an object that consumes the levels.
    #===========================================================================
    class Level_Owner
      include Core
            
      def [](data_id)
        load_level(data_id)
        return @learned[data_id]
      end
            
      def initialize(options)
        @learned ||= {}
        @options = options
        option(:source).each_index { |id|
          level = option(:source)[id]          
          keyResult = option(:key).call(id, level)
          valueResult = option(:value).call(id, level)
          load_level(keyResult, valueResult)
        }
      end
      
      def display_level_up?(data_id)
        return option(:display_message)
      end
      
      def display_level_up(data_id) # Shows levelup message
        data = @learned[data_id]
        $game_message.new_page
        $game_message.add(sprintf(Message_Format, data.name, data.lv))
      end  
      
      protected # Required: These protected methods should be overriden.
      def get_data(data_id)
        raise Errors[:missing_method].call(self, __method__)
      end
      
      def get_source
        raise Errors[:missing_method].call(self, __method__)
      end
      
      def get_source_key(index, data)
        raise Errors[:missing_method].call(self, __method__)
      end

      def get_source_value(index, data)
        raise Errors[:missing_method].call(self, __method__)
      end
      
      private
      def option(symbol)
        return @options[symbol] || method(symbol)
      end
     
      def load_level(id, lv = 1)
        data = option(:get_data).call(id) # Required by derived.
        load_data(data, lv) if data.enable_progress && @learned[id].nil?
      end
      
      def load_data(data, lv = 1) # Creates/Stores a new Level_Manager
        result = Level_Manager.new(self, data, data.id, data.name, lv)
        @learned[data.id] = result
      end
    end # Kendrick::Data_Levels::Level_Owner
  end # Kendrick::Data_Levels
end # Kendrick
#===============================================================================
# Note: This override exists to provide the call scripts for invocation in
# events and the editor.
#===============================================================================
class ::Game_Interpreter
  def set_level_progress(progress_data, level)
    progress_data.set_level(level)
  end
end # ::Game_Interpreter
