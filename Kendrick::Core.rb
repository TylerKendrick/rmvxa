=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Core
Version:    v2.0.0

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

The following core script enables common operations for use with other Kendrick
scripts.

--------------------------------------------------------------------------------
Setup:

Place this script in the materials section, above all other scripts that require
Kendrick - Core.

#===============================================================================
=end
$imported ||= {}
$imported["Kendrick::Core"] = true
#===============================================================================
# Note: The Kendrick Module will contain all Kendrick scripts and addons as a 
# namespace prefix.
#===============================================================================
module Kendrick
  #=============================================================================
  # Note: This object contains the majority of data structures in use by
  # derived Kendrick Scripts.
  #=============================================================================  
  module Core
    #===========================================================================
    # Note: This Hash exists to provide common errors.
    #===========================================================================
    @@errors = {
      # Use: Errors[:missing_method].call(self, __method__)
      :missing_method => proc { |context, method|
        className = context.class.name
        message = "#{method} must be implemented on #{className}"
        ::NotImplementedError.new(message)
      }
    } # Kendrick::Core::Errors
    def self.Errors(values)
      return @@errors = @@errors.merge(values)
    end
    #===========================================================================
    # Note: This construct only exists to store control characters for windows.
    #===========================================================================
    @@escape_characters = {
      :tab => '\t',
      :new_line => '\n',
      :carriage_return => '\r',
      :form_feed => '\f',
      :backspace => '\b',
      :bell => '\a',
      :escape => '\e',
      :space => '\s',
    }
    def self.Escape_Characters(values = nil)
      @@escape_characters = @@escape_characters.merge(values) if values
      return @@escape_characters
    end
    #===========================================================================
    # Note: This construct only exists to store regular expressions for 
    # consumption in Kendrick Scripts.
    #===========================================================================
    Regex = {
      :xml_tag => /[<|>|\&]/,
      :xml_code => /(\&\#(\w|\d)+;)/,
      :quotes => /"([^"]*)"/,
      :xml_tag => /^<(\w+)([^<]+)*(?:>(.*)<\/(?:\s)*\1>|(\s*)+\/>)$/m,
      :xml_attribute => /(\w+)\=("([^"]*)"){1}/
    } # Kendrick::Core::Regex
    #===========================================================================
    # Note: This method enables custom initializatiion after the database has 
    # loaded.
    #===========================================================================
    def self.load_database
      Kendrick::Script.resolve_dependencies
    end
  end # Kendrick::Core
  #=============================================================================
  # Note: This module is meant to act as a common mixin for addons.
  #=============================================================================
  module Script
    @@dependencies = []      
    def self.Dependencies(values = nil)
      return @@dependencies = @@dependencies.auniq(values)
    end
    
    def self.resolve_dependencies
      remaining = @@dependencies - $imported.keys.select { |x| $imported[x] }
      if !(remaining.nil? || remaining.empty?)
        names = remaining.join(", ")
        message = "The following scripts were required, but not found: { #{names} }"
        raise ::StandardError.new(message)
      end
    end
  end # Kendrick::Script
end # Kendrick
#===============================================================================
# ::Game_Battler
#===============================================================================
class ::Game_Battler < ::Game_BattlerBase
  def skill? 
    return current_action && current_action.item.is_a?(::RPG::Skill)
  end
  
  def skill
    result = skill? ? current_action.item : last_skill
    return $data_skills[result.id]
  end
  
  def data
    return actor if actor?
    return enemy if enemy?
  end
end # RPG::Game_Battler
#===============================================================================
# ::DataManager
#===============================================================================
module ::DataManager
  class << self
    alias :kendrick_core_load_database :load_database
    def load_database
      kendrick_core_load_database
      Kendrick::Core.load_database
    end
  end
end # ::DataManager
#===============================================================================
# Note: This override allows for custom control characters to be parsed.
#===============================================================================
class ::Window_Base < ::Window
  alias :kendrick_data_levels_convert_escape_characters :convert_escape_characters
  def convert_escape_characters(text)
    text = kendrick_data_levels_convert_escape_characters(text)
    Kendrick::Core.Escape_Characters.each_pair { |key, value|
      if text.include?(value)
        converted = convert_escape_character(key)
        text = text.gsub(/#{value}/, converted)
      end
    }
    return text
  end
  
  def convert_escape_character(key)
    return Kendrick::Core::Escape_Characters[key]
  end
end # ::Window_Base
#===============================================================================
# ::Array
#===============================================================================
class ::Array
  # Uses a block to select the key for the hash
  def self.to_h(array, &key)
    return ::Hash[array.collect { |item| [key.call(item), item] }]
  end
  
  # Adds two arrays together and filters for unique results.
  def self.auniq(array, other, &selector)
    result = other ? (array + other).uniq : array
    return result
  end
  
  def to_h(&key)
    return ::Array.to_h(self) { |item| key.call(item) }
  end

  def auniq(other, &selector)
    return ::Array.auniq(self, other) { |item| selector.call(item) }
  end
end # ::Array
#===============================================================================
# Note: This module exists as a helper object to clean text for parsing with my 
# Regex::Tags regular expression.  Normally, putting '<' and '>' symbols in a 
# tag's attribute value would break the regular expression.  However, this 
# construct allows for symbols to be encoded/decoded into safe symbols that can 
# be parsed by my regular expression.
#===============================================================================
class ::String
  include Kendrick
  
  def self.xml_encode(text) # Replaces text in quotes with HTML codes.
    return text.gsub(Core::Regex[:quotes]) { |m|
      # Encodes xml tags braces to their named code.
      "#{m}".gsub(Core::Regex[:xml_tag]) { |x| Noted::XmlCodes["#{x}"] }
    }
  end
  
  def self.xml_decode(text) # Replaces HTML codes in quotes with text. 
    return text.gsub(Core::Regex[:quotes]) { |m| 
      # Decodes xml codes to their symbol.
      "#{m}".gsub(Core::Regex[:xml_code]) { |x| Noted::XmlCodes.index("#{x}") }
    }
  end
    
  def xml_encode()
    return ::String.xml_encode(self)
  end
  
  def xml_decode()
    return ::String.xml_decode(self)
  end
end # ::String
