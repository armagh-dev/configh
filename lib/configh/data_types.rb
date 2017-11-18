# Copyright 2017 Noragh Analytics, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'date'
require 'time'

require_relative 'data_types/boolean'
require_relative 'data_types/encoded_string'

module Configh
  module DataTypes
    
    class TypeError < ::TypeError; end

    SUPPORTED_TYPES = %w{ integer non_negative_integer positive_integer string date timestamp boolean encoded_string symbol hash string_array symbol_array object }
    
    def self.supported?( datatype_name )
      SUPPORTED_TYPES.include?( datatype_name ) || self.respond_to?( "ensure_is_#{datatype_name}".to_sym )
    end
    
    def self.ensure_value_is_datatype( value, datatype_name, nullable = nil )

      if value.nil?
        if nullable
          return nil
        else
          raise TypeError, 'value cannot be nil'
        end
      end
      raise TypeError, "No such datatype #{ datatype_name }" unless supported?( datatype_name )
      
      dispatch = "ensure_is_#{datatype_name}"
    
      send dispatch, value, nullable: nullable

    end
  
    def self.ensure_is_integer( value, nullable: false )
      d = nil
      begin
        d = Integer( value )
      rescue => e
        raise TypeError, "value '#{value}' cannot be cast as an integer"
      end
      d
    end
  
    def self.ensure_is_non_negative_integer( value, nullable: false )
      d = ensure_is_integer( value )
      raise TypeError, "value '#{d}' is negative" if d < 0
      d
    end
  
    def self.ensure_is_positive_integer( value, nullable: false )
      d = ensure_is_integer( value )
      raise TypeError, "value '#{d}' is non-positive" if d <= 0
      d
    end
  
    def self.ensure_is_string( value, nullable: false )

      s = String( value )

      unless nullable
        raise TypeError, 'string is empty or nil' if s.nil? || s[/^\s*$/]
      end

      begin
        if s.frozen?
          unless s.encoding.to_s == 'UTF-8'
            raise TypeError, "value '#{value}' is frozen in encoding other than UTF-8"
          end
        else
          unless s.encoding.to_s == 'UTF-8'
            s = s.force_encoding 'utf-8'
          end
        end
      rescue => e
        raise TypeError, "value '#{value}' cannot be cast as a string #{e}"
      end
      s
    end

    def self.ensure_is_date( value, nullable: false )
      
      return value if value.class <= Date
      return value.to_date if value.respond_to?( :to_date )
      begin
        dt = Date.parse(value) 
      rescue
        begin
          dt = Date.strptime( value, "%m/%d/%Y" )
        rescue
          raise TypeError, "value '#{value}' cannot be cast as a date"
        end
      end
      dt
    end
  
    def self.ensure_is_timestamp( value, nullable: false )
      ts = value
      unless ts.class <= Time
        begin
          ts = Time.parse( value )
        rescue
          raise TypeError, "value '#{value}' cannot be cast as a timestamp"
        end
      end
      ts
    end
  
    def self.ensure_is_boolean( value, nullable: false )
      return value if Boolean.bool? value

      bool = nil
      if value.is_a?(String)
        down = value.downcase
        if down == 'true'
          bool = true
        elsif down == 'false'
          bool = false
        end
      end

      raise TypeError, "value '#{value}' is not boolean" if bool.nil?
      bool
    end
    
    def self.ensure_is_encoded_string( value , nullable: false)
      value = EncodedString.from_encoded( value ) if value.is_a?( String )
      raise TypeError, "value '#{value}' is not an encoded string" unless value.is_a?( EncodedString )
      value
    end
    
    def self.ensure_is_symbol( value, nullable: false )
      sym = nil
      begin
        sym = value.to_sym
      rescue
        raise TypeError, "value '#{value}' cannot be cast as a symbol"
      end
      sym
    end
    
    def self.ensure_is_hash( value, nullable: false )
      begin
        hash = value.is_a?(String) ? JSON.parse(value) : value
        if hash.is_a? Hash
          nh = {}
          hash.each{|k,v| nh[ensure_is_string(k, nullable:nullable)] = ensure_is_string(v, nullable:nullable)}
          return nh
        end
      rescue JSON::ParserError
        raise TypeError, "value '#{value}' is not a hash of strings"
      rescue
        raise TypeError, "value '#{value}' is not a hash of elements that could be converted to strings"
      end

      raise TypeError, "value '#{value}' is not a hash of strings"
    end

    def self.ensure_is_string_array(value, nullable: false)
      begin
        array = value.is_a?(String) ? JSON.parse(value) : value
        return array.collect{|i| ensure_is_string(i)} if array.is_a? Array
      rescue JSON::ParserError
        raise TypeError, "value '#{value}' is not an array of strings"
      rescue
        raise TypeError, "value '#{value}' is not an array of elements that could be converted to strings"
      end

      raise TypeError, "value '#{value}' is not an array of strings"
    end

    def self.ensure_is_symbol_array(value, nullable: false)
      begin
        array = value.is_a?(String) ? JSON.parse(value) : value
        return array.collect{|i| ensure_is_symbol(i)} if array.is_a? Array
      rescue JSON::ParserError
        raise TypeError, "value '#{value}' is not an array of symbols"
      rescue
        raise TypeError, "value '#{value}' is not an array of elements that could be converted to symbols"
      end

      raise TypeError, "value '#{value}' is not an array of symbols"
    end

    def self.ensure_is_object(value, nullable: false)
      return value
    end
  end
end
