=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Noted
Version:    v0.9.2

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Noted"] = "v0.9.2"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick::require("Kendrick::Core" => "v0.9.1+")

#===============================================================================
# Note: This module reads note sections on objects with a "note" field.  By
# using "include Kendrick::Noted" in a class or module, specified notetags can
# be parsed and handled from the "note" field.
#===============================================================================
module Kendrick::Noted
  attr_reader :tags     # The tags found on the instance object.
  attr_reader :filters  # The tags to consider when parsing.
  
  #=============================================================================
  # Note: This construct only exists to store regular expressions for 
  # consumption in Kendrick Scripts.
  #=============================================================================
  Regex = {
    :xml_character => /[<|>|\&]/,
    :xml_code => /(\&\#(\w|\d)+;)/,
    :quotes => /"(.*)"/,
    :xml_tag => /<(\w+)\s*(\w+=".*")*\s*(?:(?:\/\s*>)|(?:>(.*)<\s*\/\s*\1\s*>))/m,
    :xml_attribute => /^((?:\w+)\s*=\s*"(?:.*)")$/m
  } # Kendrick::Core::Regex
  
  #=============================================================================
  # Note: Specifies which tag names will be parsed by Kendrick::Noted.
  #=============================================================================
  @@filters = [] # Append symbols through mixins to filter valid tags.
  def self.Filters(values = nil)
    @@filters |= values unless values.nil?
    @@filters.collect(&:to_sym)
  end
  
  #=============================================================================
  # Note: This constant exists only because I was unable to get other methods
  # of HTML text encoding/decoding to work correctly.
  # 
  # Below are the following lines and errors:
  # CGI.escapeHTML("#{m}")        # Error: CGI Module doesn't exist
  # "#{m}".encode(:xml => :text)  # Error: converter not found (xml_text)
  #=============================================================================
  XmlCodes = {
    '<' => "&#lt;",
    '>' => "&#gt;",
    '&' => "&amp;",
    '"' => "&quot;"
  } # Kendrick::Core::XmlCodes
  
  # Provides a common setup for noted objects
  def load_notes(options = Tag.options)      
    @filters = options[:filters] | ::Kendrick::Noted.Filters
    @tags = Tag.parse(note, options).tap { |x| x.each(&method(:parse_tag)) }
  end
      
  # Required: Should be overriden in implementation.
  def parse_tag(tag); raise error(:missing_method); end
  
  #=============================================================================
  # Note: Any tag that conforms to the specified notetag format.
  #=============================================================================
  class Tag
    attr_reader :name
    attr_reader :innerText

    def self.options
      return {
        :filters => ::Kendrick::Noted.Filters,
        :parse_attr => proc { |x| x && !x.empty? ? Attribute.parse(x) : [] },
        :parse_text => proc { |x| x && !x.empty? ? x.xml_decode : "" }
      }
    end
    
    def self.parse(text, options = Tag.options)
      @options = Tag.options.merge(options)
      filters = @options[:filters] | ::Kendrick::Noted.Filters
      text.xml_encode.scan(Regex[:xml_tag])
        .collect(&method(:parse_match).to_proc.curry[filters]).compact
    end
    
    def self.parse_match(filters, match)
      name = match[0].to_sym
      # This allows unspecified tags to skip format checks and parsing.
      return unless filters.include?(name)
      attributes = @options[:parse_attr].call(match[1])
      innerText = @options[:parse_text].call(match[2])
      Tag.new(name, innerText, attributes)
    end
    
    def initialize(name, innerText, attributes)
      @name = name
      @innerText = innerText
      
      @attrs = case attributes
        when ::Hash then attributes
        when ::Array then Hash[attributes.collect { |x| [x.name, x] }]
        when ::NilClass
          raise TypeError.new("Expected type of Hash or Array.") 
      end
        
      validate_attrs
    end
    
    def validate_attrs
      if !valid_attributes?(@attrs)
        msgbox(@attrs)
        message = "Attributes collection was constructed improperly"
        raise StandardError.new(message)
      end
    end
    
            
    def [](name); @attrs[name]; end
    
    # Checks for "value" attribute - otherwise gets innerText.
    def value; @attrs["value"] ? @attrs["value"].value : @innerText; end
    
    def to_s
      attrs = @attrs.values.join(' ')
      attrs = " " + attrs unless attrs.nil? || attrs.empty?
      if @innerText.nil? || @innerText.empty?
        "<#@name#{attrs}/>" # self-enclosed tag if no innerText
      else # matching tags if innerText not nil
        "<#@name#{attrs}>#@innerText</#@name>"
      end  
    end
    
    def inspect; to_s; end
    
    private
    
    def valid_attributes?(attributes)
      return attributes.is_a?(::Hash) && attributes.all? { |pair|
        attributes.keys.all? { |key| key.is_a?(::String) } &&
        attributes.values.all? { |value| value.is_a?(Attribute) }
      }
    end
    
  end # Kendrick::Noted::Tag
  
  #=============================================================================
  # Note: Any tag attribute that conforms to the specified notetag format.
  #=============================================================================
  Attribute = Struct.new(:name, :value) do      
    
    def self.parse(text)
      text.xml_decode.split
        .select { |x| !(x.nil? || x.empty?) }
        .collect(&method(:get_pair))
        .collect { |key, value| Attribute.new(key, value) }
    end
      
    def self.get_pair(text)
      text.split('=').as { |key, value| [key, value.delete('"')] }
    end
    
    def to_s; "#{:name}=#{:value}"; end
    def inspect; to_s; end
    
  end # Kendrick::Noted::Attribute
  
  #=============================================================================
  # Note: This class signifies and error in the way a user-specified tag was 
  # constructed inside of the note section.
  #=============================================================================
  class MalFormattedNotetagError < SyntaxError      
    
    def initialize
      super("The note section contained a mal-formatted tag.")
    end    
  end # Kendrick::Noted::MalFormattedNotetagError
end # Kendrick::Noted

#===============================================================================
# ::Game_Interpreter
#===============================================================================
class ::Game_Interpreter
  
  def skill_tags(skill_id, options = nil)
    target = $data_skills[skill_id]
    Tag.parse(target.note, options)
  end
  
  def learning_tags(class_id, skill_id, options = nil)
    target = $data_classes[class_id].learnings.first { |x| 
      x.skill_id == skill_id
    }
    Tag.parse(target.note, options)
  end
  
  def actor_tags(actor_id, options = nil)
    target = $data_actors[actor_id]
    Tag.parse(target.note, options)
  end
  
  def enemy_tags(enemy_id, options = nil)
    target = $data_enemies[enemy_id]
    Tag.parse(target.note, options)
  end
  
  def item_tags(item_id, options = nil)
    target = $data_items[item_id]
    Tag.parse(target.note, options)
  end
  
  def weapon_tags(weapon_id, options = nil)
    target = $data_weapons[weapon_id]
    Tag.parse(target.note, options)
  end
  
  def armor_tags(armor_id, options = nil)
    target = $data_armor[armor_id]
    Tag.parse(target.note, options)
  end
  
  def state_tags(state_id, options = nil)
    target = $data_states[state_id]
    Tag.parse(target.note, options)
  end
  
  def tileset_tags(tileset_id, options = nil)
    target = $data_tilesets[tileset_id]
    Tag.parse(target.note, options)
  end
  
end # ::Game_Interpreter

#===============================================================================
# Note: This module exists as a helper object to clean text for parsing with my 
# Regex::Tags regular expression.  Normally, putting '<' and '>' symbols in a 
# tag's attribute value would break the regular expression.  However, this 
# construct allows for symbols to be encoded/decoded into safe symbols that can 
# be parsed by my regular expression.
#===============================================================================
class ::String
  
  def self.xml_encode(text) # Replaces text in quotes with HTML codes.
    text.gsub(Kendrick::Noted::Regex[:quotes]) { |m|
      # Encodes xml tags braces to their named code.
      "#{m}".gsub(Kendrick::Noted::Regex[:xml_character]) { |x| 
        Kendrick::Noted::XmlCodes["#{x}"] 
      }
    }
  end
  
  def self.xml_decode(text) # Replaces HTML codes in quotes with text. 
    text.gsub(Kendrick::Noted::Regex[:quotes]) { |m| 
      # Decodes xml codes to their symbol.
      "#{m}".gsub(Kendrick::Noted::Regex[:xml_code]) { |x| 
        Kendrick::Noted::XmlCodes.index("#{x}") 
      }
    }
  end
    
  def xml_encode; ::String.xml_encode(self); end
  def xml_decode; ::String.xml_decode(self); end  
end # ::String
