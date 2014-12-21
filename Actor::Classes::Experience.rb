=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Actor Classes Experience
Version:    v0.9.2

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
#===============================================================================
=end
$imported ||= {} 
$imported["Actor::Classes::Experience"] = "v0.9.2"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick.require("Kendrick::Data_Levels::Exp::Noted" => "v0.9.1+")

#===============================================================================
# Note: This extension enables levels and experience on classes
#===============================================================================
class ::RPG::Class
  # Store the method before including level provider.
  alias :demo_exp_for_level :exp_for_level
    
  include Kendrick::Data_Levels::Exp::Noted::Level_Provider
  alias :load_resources :load_level_provider
  
  # invoke old exp gains defined on class.
  def exp_for_level(lv, s = self); demo_exp_for_level(lv); end
  
end # ::RPG::Skill

#===============================================================================
# Note: This extension enables multiple class lv managers on an actor.
#===============================================================================
class ::RPG::Actor
  include ::Kendrick::Noted
    
  attr_reader :class_levels
  
  #-----------------------------------------------------------------------------
  # This is the main setup method.  Included to be called from DataManager.
  #-----------------------------------------------------------------------------
  def load_resources(options = {}); load_notes(:filters => [:class]); end
  
  #-----------------------------------------------------------------------------
  # Builds the default data provider hash from methods.
  #-----------------------------------------------------------------------------
  def class_level_default_options 
    {
      :data => method(:class_level_data),
      :providers => method(:class_level_providers),
      :display_message => true,
    }
  end
  
  #-----------------------------------------------------------------------------
  # This provides data so the provider hash doesn't have to.
  #-----------------------------------------------------------------------------
  def class_level_data(class_id); $data_classes[class_id]; end
    
  #-----------------------------------------------------------------------------
  # This is required by Kendrick::Noted
  #-----------------------------------------------------------------------------
  def parse_tag(tag)
    case tag.name
      when :class
        id = tag["id"].value.to_i
        class_level_providers[id] = tag["lv"].value.to_i
    end
  end
  
  #-----------------------------------------------------------------------------
  # This is used with Level Managers to provide initial levels.
  #-----------------------------------------------------------------------------
  def class_level_providers
    @class_level_providers ||= Hash.new { |h, k| h[k] = 1 }
  end
  
end # ::RPG::Actor

#===============================================================================
# Note: This extension just makes accessing things easier.
#===============================================================================
class Game_Actor
  attr_accessor :class_levels
   
  alias :class_experience_actor_initialize :initialize
  def initialize(actor_id)
    class_experience_actor_initialize(actor_id)
    
    opts = actor.class_level_default_options
    @class_levels = Kendrick::Data_Levels::Exp::Level_Owner.new(opts).tap { |x|
      x.subscribe(&method(:on_owner_manager_changed))
    }
  end
  
  #-----------------------------------------------------------------------------
  # This is invoked whenever a manager sends a notification.
  #-----------------------------------------------------------------------------
  def on_owner_manager_changed(manager, attr, value, data_id)
    if attr == :level
      owner_manager_changed_level(@class_levels, manager, value, data_id)
    end
  end  
  
  #-----------------------------------------------------------------------------
  # This is invoked whenever a manager changes the level attribute.
  #-----------------------------------------------------------------------------
  def owner_manager_changed_level(owner, manager, value, data_id)
    datum = $data_classes[data_id]
    datum.learnings.each { |learning|
      if learning.level <= value
        learn_skill(learning.skill_id)
      else
        forget_skill(learning.skill_id)
      end
    }
    manager_changed_level(manager, value, data_id)
  end
  
  #-----------------------------------------------------------------------------
  # Display the message in a game window on notify.
  #-----------------------------------------------------------------------------
  def manager_changed_level(manager, value, data_id)
    $game_message.new_page
    lv_name = ::Kendrick::Data_Levels::LevelName
    message = sprintf(::Vocab::LevelUp, manager.name, lv_name, value)
    $game_message.add(message)
  end
  
  #-----------------------------------------------------------------------------
  # Make sure you don't set class learnings here anymore.
  #-----------------------------------------------------------------------------
  def level_up; @level += 1; end
end # Game_Actor
