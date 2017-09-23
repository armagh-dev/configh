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

require 'set'
require_relative 'data_types.rb'

module Configh
  
  class ParameterDefinitionError < StandardError; end
  
  class Parameter 
    attr_accessor :name, :description, :type, :required, :default, :options, :prompt, :group, :writable, :warning, :error, :value

    def initialize(name:, description:, type:, required: false, default: nil, options: nil, prompt: nil, group: nil)
      [['name', name, 'populated_string'],
       ['description', description, 'populated_string'],
       ['type', type, 'populated_string'],
       ['required', required, 'boolean'],
       ['prompt', prompt, 'string', true],
       ['group', group, 'string', true]
      ].each do |pp_name, pp_value, pp_type, pp_nullable|
        begin
          instance_variable_set "@#{ pp_name }", DataTypes.ensure_value_is_datatype( pp_value, pp_type, pp_nullable )
        rescue DataTypes::TypeError => e
          raise ParameterDefinitionError, "#{ pp_name }: #{ e.message }"
        end
      end

      raise ParameterDefinitionError, "name cannot start with two underscores" if @name[/^__/]
      raise ParameterDefinitionError, "type #{type} unrecognized" unless DataTypes.supported?( @type )
      begin
        @default = DataTypes.ensure_value_is_datatype( default, type, true )
      rescue
        raise ParameterDefinitionError, "Default value #{default} is not a/an #{type}."
      end

      raise ParameterDefinitionError, "Options when present must be an array." unless options.nil? or options.is_a?(Array)
      if options
        begin
          @options = options.to_set
          unless @options.length == options.length
            options = options.sort
            options.length.times.each do |ix|
              options[ix] = nil unless options[ix] == options[ix+1]
            end
            options.compact!
            raise ParameterDefinitionError, "Options contains redundant values: #{options.join(",")}."
          end
        end
        @options.collect!{ |option|
          begin
            DataTypes.ensure_value_is_datatype( option, type, false )
          rescue
            raise ParameterDefinitionError, "Option #{option} is not a/an #{type}."
          end
        }
        raise ParameterDefinitionError, "Default value #{ @default } is not included in the options." if @default && !@options.include?(@default)
      end
      
    end
  
    def validate( candidate_value )
    
      value = candidate_value.nil? ? @default : candidate_value
      flagged_parameter = self.dup
    
      flagged_parameter.error = "required but no value or default provided" if @required and value.nil?
    
      begin
        value = DataTypes::ensure_value_is_datatype( value, @type, (not @required) )
      rescue DataTypes::TypeError => e
        flagged_parameter.error = "type validation failed: #{e.message}"
      end

      if @required || (!@required && value)
        if @options && !@options.include?( value )
          flagged_parameter.error = "value is not one of the options (#{@options.to_a.join(',')})"
        end
      end
    
      flagged_parameter.value = value unless flagged_parameter.error
      return flagged_parameter
    end
    
    def to_hash
      Hash[ 
        [ 'name', 'description', 'type', 'required', 'default', 'prompt', 
          'options', 'group', 'warning', 'error', 'value'
        ].collect do |pname|
          pvalue = send( pname.to_sym )
          pvalue = pvalue.to_a if pvalue && pname == 'options'
          [ pname, pvalue ]
        end
      ]
    end
  
    def self.all_errors( parameter_array )
      parameter_array.collect{ |p| [ p.group ? "Group '#{p.group}'" : nil, p.name ? "Parameter '#{p.name}'" : nil ].compact.join(' ') + ": #{p.error}" if p.error }.compact
    end
  
    def self.all_warnings( parameter_array )
      parameter_array.collect{ |p| [ p.group ? "Group '#{p.group}'" : nil, p.name ? "Parameter '#{p.name}'" : nil ].compact.join(' ') + ": #{p.warning}" if p.warning }.compact
    end
  
    def self.to_values_hash( parameter_array )
      values_hash = {}
      parameter_array.each do |p|
        values_hash[ p.group ] ||= {}
        values_hash[ p.group ][ p.name ] = p.value
      end
      return values_hash
    end
  
  end
end
