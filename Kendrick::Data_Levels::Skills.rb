=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Data Levels - Skills
Version:    v1.0.0
Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        http://git.github.com/tylerkendrick/rmvxa
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

The following script enables the ability to set levels that scale actor and 
enemy skills.  Each skill contains it's own set of parameters so they may 
level-up independently.

Learned skills and their parameters may be accessed through call-scripts, 
formulae, and the RPG::Actor.learned accessor.

Customization options are available through a simple class and note tags in the 
skill editor notes window.

--------------------------------------------------------------------------------
Setup:

Simply paste this script above your "Main" script and it will take effect.

--------------------------------------------------------------------------------
Usage:
  
  - Call-Scripts:
  
    set_actor_skill_level(actor_id, skill_id, level)
    
    set_actor_skill_level assumes that the skill_id is already contained within
    then RPG::Actor.learned array.  Otherwise, it will throw an exception.
    
    Also, refrain from prefixing ids with leading zeros.  Correct usage would
    look like the following:
    
    set_actor_skill_level(1, 1, 3)

  - Formulae:
    The parameters "item", "skill", "skill_lv", and "skill_ratio" have been
    added to the Game_Battler object and are accessible in the formula textbox
    in the editor.  This is especially useful when scaling the effects of skills
    based on their level
    
    i.e. Attack Skill: (a.atk * 4 * a.skill_ratio - b.def * 2)

    To implement this formula, follow these steps:
      1.) Open the database editor.
      2.) Open the skills tab.
      3.) Click on the "Attack" skill.
      4.) Copy/Paste the formula into the text-box labeled "Formula".
      
  - Notetags:
    
        CLASS/LEARNING:
          - <LEVEL: #> 
            #: The integer value for the level of the skill.
        SKILL:
          - <MAX_LEVEL: #> 
            #: The integer value to cap the level of the skill.
          - <PROGRESS: #>
            #: A value of "enable" or "disable".
            
#===============================================================================
=end
$imported ||= {}
$imported["Kendrick::Data_Levels::Skills"] = true
#===============================================================================
# 
#===============================================================================
module Kendrick
  Noted.Tags [ :level ]
  Script.Dependencies [
    "Kendrick::Noted",
    "Kendrick::Data_Levels"
  ]
  Core::Escape_Characters({ 
    :actor_slevels => '\a_slv(\d)+', 
    :enemy_slevels => '\e_slv(\d)+' 
  })
  
  #=============================================================================
  # Note: Need to register objects for core script setup.
  #=============================================================================
  module Core    
    class << self
      alias :kendrick_data_levels_load_database :load_database
      def load_database
        kendrick_data_levels_load_database    
        $data_classes.compact.each { |x| x.skill_setup }
        $data_skills.compact.each { |skill| skill.skill_setup }    
        $data_actors.compact.each { |actor| actor.skill_setup }
        $data_enemies.compact.each { |enemy| enemy.skill_setup }
      end
    end
  end # Kendrick::Core
  #=============================================================================
  # Note: This module contains the bulk of data structures for data level addons
  #=============================================================================
  module Data_Levels
    Message_Format = "%s is now lv.%d"  # The format of the levelup message.
    
    #===========================================================================
    # Note: Contains common logic for initializing a level owner for skill data.
    #===========================================================================
    module Battler_Data
      attr_reader :skill_levels    
      
      def load_skill_levels(options)
        @skill_levels = Level_Owner.new(options.merge({
          :get_data => proc { |id| $data_skills[id] }
        }))
      end    
    end # Kendrick::Data_Levels::Battler_Data
  end # Kendrick::Data_Levels
end #Kendrick
#===============================================================================
# This module contains all RPGVXAce Data Structures that need to be overridden
# for the Skills addon.
#===============================================================================
module RPG
  #=============================================================================
  # Note: Because skills are singleton instances, they do not contain any 
  # relation specific data to actors.  Instead, they provide the template and 
  # notetag data for an actor's skill progression data.
  #=============================================================================
  class Skill < UsableItem
    include Kendrick::Noted
    include Kendrick::Data_Levels::Level_Provider
    
    def skill_setup
      level_setup
      noted_setup
    end
    
    def parse_tag(tag) # Required by Kendrick::Core::Noted
      case tag.name
      when :max_level
        @max_lv = tag.value.to_i
      when :progress
        attr = tag["enabled"]
        value = attr ? attr.value : tag.innerText
        @enable_progress = value != "false"
      when :base_exp
        @base_exp = tag.value.to_i
      when :exp_gain
        @exp_gain = tag.value.to_i
      when :exp_formula
        @exp_formula = tag.value
      end
    end
  end # RPG::Skill
  #=============================================================================
  # Note: Extending this class simplifies calls to setup
  #=============================================================================
  class Class < BaseItem
    def skill_setup
      self.learnings.each { |learning| learning.skill_setup }
    end
    #===========================================================================
    # Note: Extending this class allows for notetags to be read from the 
    # learnings of a RPG::Class.
    #===========================================================================
    class Learning
      include Kendrick::Noted
      
      attr_reader :skill_level
        
      def skill_setup
        @skill_level = 1
        noted_setup
      end
      
      def parse_tag(tag)
        case tag.name
        when :level
          @skill_level = tag.value.to_i
        end
      end      
    end # RPG::Class::Learning
  end # RPG::Class
  #=============================================================================
  # Note: This class override allows us to make use of the progression data for 
  # actor skills.
  #=============================================================================
  class Actor < BaseItem
    include Kendrick::Data_Levels::Battler_Data
    
    def skill_setup
      load_skill_levels({
        :source => $data_classes[class_id].learnings,
        :key => proc { |i, x| x.skill_id },
        :value => proc { |i, x| x.skill_level },
        :display_message => true
      })
    end
  end # RPG::Actor
  #=============================================================================
  # Note: This class override allows us to make use of the progression data for 
  # enemy skills.
  #=============================================================================
  class Enemy < BaseItem
    include Kendrick::Data_Levels::Battler_Data
    
    def skill_setup
      load_skill_levels({
        :source => actions,
        :key => proc { |i, x| x.skill_id },
        :value => proc { |i, x| $data_skills[x.skill_id].max_lv },
        :display_message => false
      })
    end
  end # RPG::Enemy
end # RPG
#===============================================================================
# Note: This class override exists for the sole purpose of exposing data
# to skill formulae.
#===============================================================================
class ::Game_Battler < ::Game_BattlerBase
  def skill_levels # Make peace with Demeter
    return data.skill_levels
  end

  def skill_level
    return skill_levels[skill.id]
  end
  
  def slv
    return skill_level.lv
  end
  
  def smax_lv
    return skill.max_lv
  end
  
  def sratio
    # Remember to convert to_f, otherwise will return either 0 or 1.
    return slv / smax_lv.to_f
  end
end # ::Game_Battler
#===============================================================================
# Note: This override exists in order to display the actor's skill level as a
# part of the skill's name - as well as displaying the skill exp.
#===============================================================================
class ::Window_SkillList < ::Window_Selectable
  def draw_item_name(item, x, y, enabled = true, width = 172) # override
    return unless item
    draw_icon(item.icon_index, x, y, enabled)
    change_color(normal_color, enabled)
    # The only change to this override was the provider for the name.
    learned = @actor.skill_levels[item.id]
    name = learned.nil? ? item.name : learned.name
    draw_text(x + 24, y, width, line_height, name)
 end
end # ::Window_SkillList
#===============================================================================
# Note: This override exists to provide the call scripts for invocation in
# events and the editor.
#===============================================================================
class ::Game_Interpreter
  def set_actor_skill_level(actor_id, skill_id, level)
    owner = $data_actors[actor_id]
    set_owner_skill_level(owner, skill_id, level)
  end
  
  def set_enemy_skill_level(enemy_id, skill_id, level)
    owner = $game_troop.members[enemy_id]
    set_owner_skill_level(owner, skill_id, level)
  end
  
  def set_owner_skill_level(owner, skill_id, level)
    progress_data = owner.skill_levels[skill_id]
    set_level_progress(progress_data, level)
  end
end # ::Game_Interpreter
