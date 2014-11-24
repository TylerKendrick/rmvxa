=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Core
Version:    v1.1.1

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

1.) Place this script in the materials section, above all other scripts that require
Kendrick - Core.

2.) Add tags that you wish to parse to Kendrick::Core:Noted.Tags
i.e. Kendrick::Core::Noted.Tags += [ :my_tag ]

3.) Create a new class that implements Kendrick::Core::Noted as a mixin

i.e. 
    class MY_CLASS
      include Kendrick::Core::Noted
      
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
$imported["Kendrick::Core"] = true
#===============================================================================
# Note: The Kendrick Module will contain all Kendrick scripts and addons as a 
# namespace prefix.
#===============================================================================
module Kendrick
  module Core
    #===========================================================================
    # Note: This construct only exists to store regular expressions for 
    # consumption in Kendrick Scripts.
    #===========================================================================
    Regex = {
      :XmlTag => /[<|>|\&]/,
      :XmlCode => /(\&\#(\w|\d)+;)/,
      :Quotes => /"([^"]*)"/,
      :Tag => /^<(\w+)([^<]+)*(?:>(.*)<\/(?:\s)*\1>|(\s*)+\/>)$/m,
      :Attribute => /(\w+)\=("([^"]*)"){1}/
    } # Kendrick::Core::Regex
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
    #===========================================================================
    # Note: This module is meant to act as a common mixin for addons.
    #===========================================================================
    module Script
      @@dependencies = []
      
      class << self
        def Dependencies(values = nil)
          @@dependencies = (@@dependencies + values).uniq if !values.nil?
          return @@dependencies
        end
        
        def resolve_dependencies
          remaining = @@dependencies - $imported.keys.select { |x| $imported[x] }
          if !(remaining.nil? || remaining.empty?)
            names = remaining.join(", ")
            message = "The following scripts were required, but not found: { #{names} }"
            raise ::StandardError.new(message)
          end
        end
      end
    end # Kendrick::Core::Script
    #===========================================================================
    # Note: This module exists as a helper object to clean text for parsing with
    # my Regex::Tags regular expression.  Normally, putting '<' and '>' symbols
    # in an tag's attribute value would break the regular expression.  However,
    # this construct allows for symbols to be encoded/decoded into safe symbols
    # that can be parsed by my regular expression.
    #===========================================================================
    class ::String
      def self.xml_encode(text) # Replaces text in quotes with HTML codes.
        return text.gsub(Regex[:Quotes]) { |m|
          # Encodes xml tags braces to their named code.
          "#{m}".gsub(Regex[:XmlTag]) { |x| XmlCodes["#{x}"] }
        }
      end
      
      def self.xml_decode(text) # Replaces HTML codes in quotes with text. 
        return text.gsub(Regex[:Quotes]) { |m| 
          # Decodes xml codes to their symbol.
          "#{m}".gsub(Regex[:XmlCode]) { |x| XmlCodes.index("#{x}") }
        }
      end
        
      def xml_encode()
        return ::String.xml_encode(self)
      end
      
      def xml_decode()
        return ::String.xml_decode(self)
      end
    end # ::String
    #===========================================================================
    # Note: This module reads note sections on objects with a "note" field.  By
    # using "include Kendrick::Noted" in a class or module, specified notetags
    # can be parsed and handled from the "note" field.
    #===========================================================================
    module Noted
      @@tags = [] # Append symbols through mixins to filter valid tags.

      attr_reader :tags # The tags found on the instance object.

      def self.Tags(values = nil)
        @@tags = (@@tags + values).uniq if !values.nil?
        @@tags.collect { |x| x.to_sym } # Ensure all are read as symbols
      end
      
      def setup # Provides a setup method for object constructed without initialize.
        @tags = Tag.parse(self.note.xml_encode)
        # parse_tag MUST be implemented for mixins
        @tags.each_value { |tag| parse_tag(tag) }
      end
      
      class Tag
        attr_reader :name
        attr_reader :innerText
        
        Attribute = Struct.new(:name, :value) do
          def self.valid?(text)
            return Regex[:Attribute].match(text)
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
        end # Kendrick::Core::Noted::Tag::Atrribute
                
        def initialize(name, innerText, attributes)
          @name = name
          @innerText = innerText
          @attributes = attributes if attributes.is_a?(::Hash)
          @attributes = Array.to_h(attributes) { |x| x.name } if attributes.is_a?(::Array)
          if @attributes.nil?
            raise TypeError.new("Expected type of Hash or Array.") 
          end
          if !valid_attributes?(@attributes)
            raise StandardError.new("Attributes collection was constructed improperly") 
          end
        end
                
        def [](name)
          return @attributes[name]
        end
        
        def value
          return @attributes["value"] ? @attributes["value"].value : @innerText
        end
        
        def self.parse(text)
          tags = {}
          Regex[:Tag].match(text) { |m|
            # Must convert to symbol to match Tags
            name = m[1].intern            
            # This allows unspecified tags to skip format checks and parsing.
            next unless Noted.Tags.include?(name)
            # Convert to has by name for tag indexing.
            attributes = Attribute.parse(m[2])
            innerText = m[3].xml_decode if !m[3].empty?
            tag = Tag.new(name, innerText, attributes)
            tags[name] = tag
          }
          return tags
        end

        def to_s
          attrs = @attributes.values
            .collect{ |a| " " + a.to_s }
            .reduce(:+)
          if @innerText.nil? || @innerText.empty?
            return "<#@name#{attrs}/>"
          else
            return "<#@name#{attrs}>#@innerText</#@name>"
          end  
        end
        
        private
        def valid_attributes?(attributes)
          return attributes.is_a?(::Hash) && attributes.all? { |pair|
            attributes.keys.all? { |key| key.is_a?(::String) } &&
            attributes.values.all? { |value| value.is_a?(Attribute) }
          }
        end
      end # Kendrick::Core::Noted::Tag
      #=========================================================================
      # Note: This class signifies and error in the way a user-specified tag was 
      # constructed inside of the note section.
      #=========================================================================
      class MalFormattedNotetagError < Exception      
        def initialize()
          super("The note section contained a mal-formatted tag.")
        end
      end # Kendrick::Core::Noted::MalFormattedNotetagError
    end # Kendrick::Core::Noted
    
    def self.load_database
      Kendrick::Core::Script.resolve_dependencies
    end
  end # Kendrick::Core
end # Kendrick
#===============================================================================
# DataManager
#===============================================================================
module DataManager
  class << self
    alias :kendrick_core_load_database :load_database
  end
  def self.load_database
    kendrick_core_load_database
    Kendrick::Core.load_database
  end
end # DataManager
#===============================================================================
# Array
#===============================================================================
class ::Array
  # Uses a block to select the key for the hash
  def self.to_h(array, &key)
    return Hash[array.collect { |item| [key.call(item), item] }]
  end
  
  def to_h(&key)
    return ::Array.to_h(self)
  end
end # ::Array
