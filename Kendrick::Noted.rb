=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Noted
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
  Script.Dependences ["Kendrick::Core"]
  
  #=============================================================================
  # Note: This module reads note sections on objects with a "note" field.  By
  # using "include Kendrick::Noted" in a class or module, specified notetags can
  # be parsed and handled from the "note" field.
  #=============================================================================
  module Noted
    attr_reader :tags # The tags found on the instance object.
    
    #===========================================================================
    # Note: Specifies which tag names will be parsed by Kendrick::Noted.
    #===========================================================================
    @@tags = [] # Append symbols through mixins to filter valid tags.
    def self.Tags(values = nil)
      @@tags = @@tags.auniq(values)
      # Ensure all are read as symbols
      return @@tags.collect { |x| x.to_sym };
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

    def noted_setup # Provides a setup for object constructed without initialize
      @tags = Tag.parse(note.xml_encode)
      @tags.each_value { |tag| parse_tag(tag) }
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
      
      def self.parse(text)
        tags = {}
        Core::Regex[:xml_tag].match(text) { |m|
          # Must convert to symbol to match Tags
          name = m[1].intern            
          # This allows unspecified tags to skip format checks and parsing.
          next unless Noted.Tags.include?(name)
          # Convert to has by name for tag indexing.
          attributes = Attribute.parse(m[2])
          innerText = m[3].xml_decode if !m[3].empty?
          tags[name] = Tag.new(name, innerText, attributes)
        }
        return tags
      end
              
      def initialize(name, innerText, attributes)
        @name = name
        @innerText = innerText
        @attributes = attributes if attributes.is_a?(::Hash)
        @attributes = attributes.to_h { |x| x.name } if attributes.is_a?(::Array)
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
        attrs = @attributes.values
          .collect{ |a| " " + a.to_s }
          .reduce(:+) # joins all strings together with initial space.
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
          attributes.values.all? { |value| value.is_a?(Attribute) }
        }
      end
    end # Kendrick::Noted::Tag
    #===========================================================================
    # Note: Any tag attribute that conforms to the specified notetag format.
    #===========================================================================
    Attribute = Struct.new(:name, :value) do
      def self.valid?(text)
        return Core::Regex[:xml_attribute].match(text)
      end
      
      def self.parse(text)
        return text.xml_decode.split.collect { |attr| 
          raise MalFormattedNotetagError.new unless valid?(attr)
          pair = attr.split('=')
          Attribute.new(pair[0], pair[1].delete('"'))
        }
      end
      
      def to_s
        return sprintf('%s="%s"', name, value)
      end
      
      def inspect
        return to_s
      end
    end # Kendrick::Noted::Attribute
    #=========================================================================
    # Note: This class signifies and error in the way a user-specified tag was 
    # constructed inside of the note section.
    #=========================================================================
    class MalFormattedNotetagError < SyntaxError      
      def initialize()
        super("The note section contained a mal-formatted tag.")
      end
    end # Kendrick::Noted::MalFormattedNotetagError
  end # Kendrick::Noted
end # Kendrick
