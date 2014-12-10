=begin
#===============================================================================
Author:     Tyler Kendrick
Title:      Kendrick - Versions
Version:    v0.9.1

Language:   RGSS3
Framework:  RPG Maker VX Ace
Git:        https://github.com/TylerKendrick/rmvxa
--------------------------------------------------------------------------------
=end
$imported ||= {}
$imported["Kendrick::Versions"] = "v0.9.1"
#===============================================================================
# Note: Need to register objects for core script setup.
#===============================================================================
Kendrick.require("Kendrick::Core" => "v0.9.1")

module Kendrick
  #=============================================================================
  # Note: VersionInfos only contain the major, minor, and build numbers in the
  # format ("vM.m.b").  The format does not allow for inferred minor or build #s
  #=============================================================================
  class VersionInfo
    include Comparable
    
    attr_reader :major
    attr_reader :minor
    attr_reader :build
    
    def initialize(major = 1, minor = 0, build = 0)
      @major = major
      @minor = minor
      @build = build
    end
    
    def to_s
      return "v#{@major}.#{@minor}.#{@build}"
    end
    
    def inspect
      return to_s
    end
    
    def >(other)
      return compare(:>, other)
    end
    
    def <(other)
      return compare(:<, other)
    end

    def ==(other)
      return @major == other.major &&
        @minor == other.minor &&
        @build == other.build
    end
      
    def !=(other)
      return !(self == other)
    end

    #---------------------------------------------------------------------------
    # The spaceship operator is used when comparing ranges.
    #---------------------------------------------------------------------------
    def <=>(other)
      return 1 if self > other
      return -1 if self < other
      return 0 if self == other
      return nil
    end
    
    #---------------------------------------------------------------------------
    # This method converts text in the format "vM.m.b" to a VersionInfo.
    #---------------------------------------------------------------------------
    def self.parse(text, &callback)
      results = text.scan(/^v(\d+).(\d+).(\d+)$/, &callback).first
      return new(results[0].to_i, results[1].to_i, results[2].to_i)
    end
    
    private 

    #---------------------------------------------------------------------------
    # This nifty doo-dad just applies an operator to each version number and 
    # concatenates the comparison results.
    #---------------------------------------------------------------------------
    def compare(operator, other)
      major = @major.send(operator, other.major)
      minor = @minor.send(operator, other.minor)
      build = @build.send(operator, other.build)
      
      return major || 
        (@major == other.major && minor) ||
        (@major == other.major && @minor == other.minor && build)
    end
      
  end # Kendrick::VersionInfo
  
  #-----------------------------------------------------------------------------
  # This just simplifies accessibility.
  #-----------------------------------------------------------------------------
  Version = Kendrick::VersionInfo.parse($imported["Kendrick::Core"])

  #=============================================================================
  # Note: This module extention handles dependency resolution.
  #=============================================================================
  module Core
    class << self
      
      alias :versioning_resolve_dependency :resolve_dependency
      def resolve_dependency(name, value, &on_error)
        versioning_resolve_dependency(name, value, &on_error)
        
        case value
          when ::String            
            # See if string can be converted to boolean.
            as_boolean = value.to_b
            resolve_string(name, value, &on_error) if as_boolean.nil?
            resolve_bool(name, as_boolean, &on_error) unless as_boolean.nil?
          when ::Boolean
            resolve_bool(name, value, &on_error)
        end
      end

      private
    
      #-------------------------------------------------------------------------
      # Do errors for script boolean include mismatches.
      #-------------------------------------------------------------------------
      def resolve_bool(name, value, &on_error)
        # check if script is imported.
        imported = $imported.has_key?(name)
        # store value of script (true or false)
        result = imported ? $imported[name] : false
        # compare value with expectation.
        result = value == result if result.is_a?(::Boolean)
        
        on_error.call(name, value, :bool_include) unless result
      end
      
      #-------------------------------------------------------------------------
      # Do errors for invalid string markups and version mismatches.
      #-------------------------------------------------------------------------
      def resolve_string(name, value, &on_error)
        version_regexp = /v(\d+).(\d+).(\d+)/
        # read target imported script version number 
        imported = Kendrick::VersionInfo.parse($imported[name])
              
        string_exact_scan(value, version_regexp, imported)
        string_min_scan(value, version_regexp, imported)
        string_range_scan(value, version_regexp, imported)
      end 
      
      #-------------------------------------------------------------------------
      # Check a string for an exact version match.
      #-------------------------------------------------------------------------
      def string_exact_scan(value, version_regexp, imported)
        exact_regexp = /^#{version_regexp}$/
        
        # try to find an exact version number
        value.scan(exact_regexp).each { |match|
          version = new_version_info(*match.collect(&:to_i))
          condition = version != imported && on_error
          on_error.call(name, version, :exact_version) if condition
        }
      end
      
      #-------------------------------------------------------------------------
      # Check a string for minimum versions.
      #-------------------------------------------------------------------------
      def string_min_scan(value, version_regexp, imported)
        min_regexp = /^#{version_regexp}\+$/
        
        # try to find an version number followed by a '+'
        value.scan(min_regexp) { |match|
          version = new_version_match(*match.collect(&:to_i))
          condition = version > imported && on_error
          on_error.call(name, version, :min_version) if condition
        }
      end
  
      #-------------------------------------------------------------------------
      # Check a string for version ranges.
      #-------------------------------------------------------------------------
      def string_range_scan(value, version_regexp, imported)
        exact_regexp = /^#{version_regexp}$/
        # allow "..", "...", and "-" range qualifiers.
        range_regexp = /^(#{version_regexp})(?:\.{2, 3}|\-)(#{version_regexp})$/
        
        # try to find a range of version numbers.
        value.scan(range_regexp) { |match|
          min_match, max_match = match
          min_match = min_match.scan(exact_regexp)[0..2]
          max_match = max_match.scan(exact_regexp)[3..5]
          min = new_version_match(*min_match.collect(&:to_i))
          max = new_version_match(*max_match.collect(&:to_i))
          condition = imported === min..max && on_error
          on_error.call(name, imported, :range_version) if condition
        }
      end
      
      #-------------------------------------------------------------------------
      # Simplifies creation of version info instances as overridable method.
      #-------------------------------------------------------------------------
      def new_version_info(major, minor, build)
        return Kendrick::VersionInfo.new(major, minor, build)
      end
      
    end # class << self
  
  end # Kendrick::Core

end # Kendrick
