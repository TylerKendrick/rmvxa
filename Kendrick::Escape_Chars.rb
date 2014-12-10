=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Escape Characters
Version:    v0.9.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Escape_Chars"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick.require("Kendrick::Core" => "v0.9.1")

#===============================================================================
# Note: This singleton module handles escape chars found in text.
#===============================================================================
module Kendrick::Escape_Chars
  class << self
    #---------------------------------------------------------------------------
    # This method obtains access to the class varaible.
    #---------------------------------------------------------------------------
    def [](values = nil)
      @@escape_characters = @@escape_characters.merge(values) if values
      return @@escape_characters
    end
    
    def parse(text)
      @@escape_characters.each_pair { |key, value|
        if text.include?(value)
          # defer evaluation to method and allow overloading.
          converted = handle_escape_character(key)
          # replace the character with result of handle method.
          text = text.gsub(/#{value}/, converted)
        end
      }
      return text
    end
    
    protected
    
    #---------------------------------------------------------------------------
    # This method returns the hash for control characters.
    #---------------------------------------------------------------------------
    def build_characters
      return {
        :tab => '\t',
        :new_line => '\n',
        :carriage_return => '\r',
        :form_feed => '\f',
        :backspace => '\b',
        :bell => '\a',
        :escape => '\e',
        :space => '\s',
      }
    end    
    
    private
    
    #---------------------------------------------------------------------------
    # This method is called by implemented classes to handle a common char.
    #---------------------------------------------------------------------------
    def handle_escape_character(key)
      return @@escape_characters[key]
    end
  
  end # class << self
  
  #=============================================================================
  # Note: This construct only exists to store control characters for windows.
  #=============================================================================
  @@escape_characters = ::Kendrick::Escape_Chars.build_characters
  
end # Kendrick::Escape_Chars

#===============================================================================
# Note: This override allows for custom control characters to be parsed.
#===============================================================================
class ::Window_Base
  
  alias :kendrick_data_levels_convert_escape_characters :convert_escape_characters
  def convert_escape_characters(text)
    text = kendrick_data_levels_convert_escape_characters(text)
    return ::Kendrick::Escape_Chars.parse(text)
  end
    
end # ::Window_Base
