# Copyright 2016 Noragh Analytics, Inc.
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

    SUPPORTED_TYPES = %w{ integer non_negative_integer positive_integer string populated_string date timestamp boolean encoded_string symbol hash string_array symbol_array }
    
    def self.supported?( datatype_name )
      SUPPORTED_TYPES.include?( datatype_name ) || self.respond_to?( "ensure_is_#{datatype_name}".to_sym )
    end
    
    def self.ensure_value_is_datatype( value, datatype_name, nullable = nil )
    
      if nullable
        return nil if (value.nil? or ( value.is_a?(String) and value[/^\s*$/] and datatype_name != "populated_string"))
      else
        raise TypeError, "value cannot be nil" if value.nil?
      end
      raise TypeError, "No such datatype #{ datatype_name }" unless supported?( datatype_name )
      
      dispatch = "ensure_is_#{datatype_name}"
    
      send dispatch, value

    end
  
    def self.ensure_is_integer( value )
      d = nil
      begin
        d = Integer( value )
      rescue => e
        raise TypeError, "value #{value} cannot be cast as an integer"
      end
      d
    end
  
    def self.ensure_is_non_negative_integer( value )
      d = ensure_is_integer( value )
      raise TypeError, "value #{ d } is negative" if d < 0
      d
    end
  
    def self.ensure_is_positive_integer( value )
      d = ensure_is_integer( value )
      raise TypeError, "value #{d} is non-positive" if d <= 0
      d
    end
  
    def self.ensure_is_string( value )
      begin
        s = String( value )
        if s.frozen?
          unless s.encoding.to_s == 'UTF-8'
            raise TypeError, "value #{value} is frozen in encoding other than UTF-8"
          end
        else
          unless s.encoding.to_s == 'UTF-8'
            s = s.force_encoding 'utf-8'
          end
        end
      rescue
        raise TypeError, "value #{value} cannot be cast as a string"
      end
      s
    end
    
    def self.ensure_is_populated_string( value )
      s = ensure_is_string( value )
      raise TypeError, "string is empty or nil" unless s[ /[^\s]/]
      s
    end
    
    def self.ensure_is_date( value )
      
      return value if value.class <= Date
      return value.to_date if value.respond_to?( :to_date )
      begin
        dt = Date.parse(value) 
      rescue
        begin
          dt = Date.strptime( value, "%m/%d/%Y" )
        rescue
          raise TypeError, "value #{ value } cannot be cast as a date"
        end
      end
      dt
    end
  
    def self.ensure_is_timestamp( value )
      ts = value
      unless ts.class <= Time
        begin
          ts = Time.parse( value )
        rescue
          raise TypeError, "value #{value} cannot be cast as a timestamp"
        end
      end
      ts
    end
  
    def self.ensure_is_boolean( value )
      if value.is_a?( String ) and [ 'true', 'false' ].include?( value.downcase )
        value = eval(value)
      end
      raise TypeError, "value #{value} is not boolean" unless Boolean.bool?( value ) 
      value
    end
    
    def self.ensure_is_encoded_string( value )
      value = EncodedString.from_encoded( value ) if value.is_a?( String )
      raise TypeError, "value #{value} is not an encoded string" unless value.is_a?( EncodedString )
      value
    end
    
    def self.ensure_is_symbol( value )
      sym = nil
      begin
        sym = value.to_sym
      rescue 
        raise TypeError, "value #{value} cannot be cast as a symbol"
      end
    end
    
    def self.ensure_is_hash( value )
      
      return value if value.is_a?( Hash )
      begin
        h = eval( value )
        return h if h.is_a?( Hash )
      rescue; end
      raise TypeError, "value #{value} cannot be cast as a hash"
    end

    def self.ensure_is_string_array(value)
      begin
        val = (value.is_a?(String)) ? eval(value) : value
        return val.collect{|i| ensure_is_string(i)} if val.is_a? Array
      rescue
        raise TypeError, "value #{value} is not an array of elements that could be converted to strings"
      end
      raise TypeError, "value #{value} is not an array of strings"
    end

    def self.ensure_is_symbol_array(value)
      begin
        val = (value.is_a?(String)) ? eval(value) : value
        return val.collect{|i| ensure_is_symbol(i)} if val.is_a? Array
      rescue
        raise TypeError, "value #{value} is not an array of elements that could be converted to symbols"
      end
      raise TypeError, "value #{value} is not an array of symbols"
    end
  end
end