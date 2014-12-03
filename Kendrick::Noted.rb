=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Noted
Version:    v1.1.0

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

This script allows for parsing game data note sections for well-formatted,
registered tags.  To register tags, simply append to the Tags variable:
i.e. Kendrick::Core::Noted.Tags += [ :new_value ]

In the note sections, the tags must be enclosed - either with a matching named
end-tag ("<name>content<name/>") or through a self enclosed tag ("<name/>").

Tags may also include attributes as named key/value pairs. Valid attribute keys
must be at least once space away from the tag's name and must not contain any
punctuation or special characters.  Valid attribute values must be contained
within quotation marks and may not contain escape characters.

  Valid Examples:
    <name attr="value"/>
    <name atr="3"></name>
    <name value="'attr'" />
  Invalid Examples:
    <nameattr="value"/>
    <name atr=3></name>
    <name value="\'attr\'" />

--------------------------------------------------------------------------------
Setup:

1.) Place this script in the materials section, above all other scripts that 
require Kendrick - Core.

2.) Add tags that you wish to parse to Kendrick::Core:Noted.Tags
i.e. Kendrick::Noted.Tags += [ :my_tag ]

3.) Create a new class that implements Kendrick::Core::Noted as a mixin

i.e. 
    class MY_CLASS
      include Kendrick::Noted
      
      def parse_tag(tag)
        case tag.name
        when :my_tag
          msgbox_p("TAG FOUND") 
        end
      end  
    end # MY_CLASS

#===============================================================================
=end
$imported ||= {}
$imported["Kendrick::Noted"] = true
#===============================================================================
# Note: The Kendrick Module contains all Kendrick scripts and addons as a 
# namespace prefix.
#===============================================================================
module Kendrick
  #=============================================================================
  # Note: Need to register objects for core script setup.
  #=============================================================================
  Script.Dependencies ["Kendrick::Core"]
  
  #=============================================================================
  # Note: This module reads note sections on objects with a "note" field.  By
  # using "include Kendrick::Noted" in a class or module, specified notetags can
  # be parsed and handled from the "note" field.
  #=============================================================================
  module Noted
    attr_reader :tags     # The tags found on the instance object.
    attr_reader :filters  # The tags to consider when parsing.
    
    #===========================================================================
    # Note: This construct only exists to store regular expressions for 
    # consumption in Kendrick Scripts.
    #===========================================================================
    Regex = {
      :xml_character => /[<|>|\&]/,
      :xml_code => /(\&\#(\w|\d)+;)/,
      :quotes => /"(.*)"/,
      :xml_tag => /<(\w+)\s*(\w+=".*")*\s*(?:(?:\/\s*>)|(?:>(.*)<\s*\/\s*\1\s*>))/m,
      :xml_attribute => /^((?:\w+)\s*=\s*"(?:.*)")$/m
    } # Kendrick::Core::Regex
    #===========================================================================
    # Note: Specifies which tag names will be parsed by Kendrick::Noted.
    #===========================================================================
    @@filters = [] # Append symbols through mixins to filter valid tags.
    def self.Filters(values = nil)
      @@filters |= values unless values.nil?
      # Ensure all are read as symbols
      return @@filters.collect { |x| x.to_sym }
    end
    #===========================================================================
    # Note: This constant exists only because I was unable to get other methods
    # of HTML text encoding/decoding to work correctly.
    # 
    # Below are the following lines and errors:
    # CGI.escapeHTML("#{m}")        # Error: CGI Module doesn't exist
    # "#{m}".encode(:xml => :text)  # Error: converter not found (xml_text)
    #===========================================================================
    XmlCodes = {
      '<' => "&#lt;",
      '>' => "&#gt;",
      '&' => "&amp;",
      '"' => "&quot;"
    } # Kendrick::Core::XmlCodes
    
    # Provides a setup for object constructed without initialize
    def noted_setup(options = Tag.options)      
      @filters = options[:filters] | Noted.Filters
      @tags = Tag.parse(note, options)
      @tags.each { |tag| parse_tag(tag) }
    end
    
    def parse_tag(tag) # Required: Should be overriden in implementation.
      raise Errors[:missing_method].call(self, __method__)
    end
    #===========================================================================
    # Note: Any tag that conforms to the specified notetag format.
    #===========================================================================
    class Tag
      attr_reader :name
      attr_reader :innerText

      def self.options
        return {
          :filters => Noted.Filters,
          :parse_attr => proc { |x| x && !x.empty? ? Attribute.parse(x) : [] },
          :parse_text => proc { |x| x && !x.empty? ? x.xml_decode : "" }
        }
      end
      
      def self.parse(text, options = Tag.options)
        @options = Tag.options.merge(options)
        filters = @options[:filters] | Noted.Filters
        tags = text.xml_encode.scan(Regex[:xml_tag]).collect { |m|
          # Must convert to symbol to match Tags
          name = m[0].intern
          # This allows unspecified tags to skip format checks and parsing.
          next unless filters.include?(name)
          attributes = @options[:parse_attr].call(m[1])
          innerText = @options[:parse_text].call(m[2])
          tag = Tag.new(name, innerText, attributes)
          ####msgbox_p(tag)
          tag
        }
        ####msgbox_p(tags) unless tags.empty?
        return tags.compact
      end
              
      def initialize(name, innerText, attributes)
        @name = name
        @innerText = innerText
        @attributes = attributes if attributes.is_a?(::Hash)
        @attributes = ::Array.to_h(attributes) { |x| x.name } if attributes.is_a?(::Array)
        if @attributes.nil?
          raise TypeError.new("Expected type of Hash or Array.") 
        end
        if !valid_attributes?(@attributes)
          message = "Attributes collection was constructed improperly"
          raise StandardError.new(message)
        end
      end
              
      def [](name)
        return @attributes[name]
      end
      
      def value # Checks for "value" attribute - otherwise gets innerText.
        return @attributes["value"] ? @attributes["value"].value : @innerText
      end
      
      def to_s
        attrs = @attributes.values.join(' ')
        attrs = " " + attrs unless attrs.nil? || attrs.empty?
        if @innerText.nil? || @innerText.empty?
          return "<#@name#{attrs}/>" # self-enclosed tag if no innerText
        else # matching tags if innerText not nil
          return "<#@name#{attrs}>#@innerText</#@name>"
        end  
      end
      
      def inspect
        to_s
      end
      
      private
      def valid_attributes?(attributes)
        return attributes.is_a?(::Hash) && attributes.all? { |pair|
          attributes.keys.all? { |key| key.is_a?(::String) } &&
          attributes.values.all? { |value| value.is_a?(Noted::Attribute) }
        }
      end
    end # Kendrick::Noted::Tag
    #===========================================================================
    # Note: Any tag attribute that conforms to the specified notetag format.
    #===========================================================================
    Attribute = Struct.new(:name, :value) do      
      def self.parse(text)
        return text.xml_decode.split.collect { |attr|
          if !(attr.nil? || attr.empty?)
            pair = attr.split('=')
            Attribute.new(pair[0], pair[1].sub('"', ""))
          end
        }.compact
      end
      
      def to_s
        return "#{name}=#{value}"
      end
      
      def inspect
        return to_s
      end
    end # Kendrick::Noted::Attribute
    #===========================================================================
    # Note: This class signifies and error in the way a user-specified tag was 
    # constructed inside of the note section.
    #===========================================================================
    class MalFormattedNotetagError < SyntaxError      
      def initialize()
        super("The note section contained a mal-formatted tag.")
      end
    end # Kendrick::Noted::MalFormattedNotetagError
    #===========================================================================
    # Note: This module simply allows for database objects to have their note
    # sections parsed.
    #===========================================================================
    module Parser
      def skill_tags(skill_id, options = nil)
        target = $data_skills[skill_id]
        return Tag.parse(target.note, options)
      end
      
      def learning_tags(class_id, skill_id, options = nil)
        target = $data_classes[class_id].learnings.first { |x| 
          x.skill_id == skill_id
        }
        return Tag.parse(target.note, options)
      end
      
      def actor_tags(actor_id, options = nil)
        target = $data_actors[actor_id]
        return Tag.parse(target.note, options)
      end
      
      def enemy_tags(enemy_id, options = nil)
        target = $data_enemies[enemy_id]
        return Tag.parse(target.note, options)
      end
      
      def item_tags(item_id, options = nil)
        target = $data_items[item_id]
        return Tag.parse(target.note, options)
      end
      
      def weapon_tags(weapon_id, options = nil)
        target = $data_weapons[weapon_id]
        return Tag.parse(target.note, options)
      end
      
      def armor_tags(armor_id, options = nil)
        target = $data_armor[armor_id]
        return Tag.parse(target.note, options)
      end
      
      def state_tags(state_id, options = nil)
        target = $data_states[state_id]
        return Tag.parse(target.note, options)
      end
      
      def tileset_tags(tileset_id, options = nil)
        target = $data_tilesets[tileset_id]
        return Tag.parse(target.note, options)
      end
    end # Kendrick::Noted::Parser
  end # Kendrick::Noted
end # Kendrick
#===============================================================================
# ::Game_Interpreter
#===============================================================================
class ::Game_Interpreter
  include Kendrick::Noted::Parser
end # ::Game_Interpreter
#===============================================================================
# Note: This module exists as a helper object to clean text for parsing with my 
# Regex::Tags regular expression.  Normally, putting '<' and '>' symbols in a 
# tag's attribute value would break the regular expression.  However, this 
# construct allows for symbols to be encoded/decoded into safe symbols that can 
# be parsed by my regular expression.
#===============================================================================
class ::String
  include Kendrick::Noted
  
  def self.xml_encode(text) # Replaces text in quotes with HTML codes.
    return text.gsub(Regex[:quotes]) { |m|
      # Encodes xml tags braces to their named code.
      "#{m}".gsub(Regex[:xml_character]) { |x| XmlCodes["#{x}"] }
    }
  end
  
  def self.xml_decode(text) # Replaces HTML codes in quotes with text. 
    return text.gsub(Regex[:quotes]) { |m| 
      # Decodes xml codes to their symbol.
      "#{m}".gsub(Regex[:xml_code]) { |x| XmlCodes.index("#{x}") }
    }
  end
    
  def xml_encode()
    return ::String.xml_encode(self)
  end
  
  def xml_decode()
    return ::String.xml_decode(self)
  end
end # ::String
