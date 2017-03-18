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

require_relative 'data_types.rb'

module Configh
  
  class ParameterDefinitionError < StandardError; end
  
  class Parameter 
    attr_accessor :name, :description, :type, :required, :default, :prompt, :group, :writable, :warning, :error, :value
  
    def initialize( name:, description:, type:, required: false, default: nil, prompt: nil, group: nil )
      
      [ [ 'name',        'populated_string' ],
        [ 'description', 'populated_string' ],
        [ 'type',        'populated_string' ],
        [ 'required',    'boolean' ],
        [ 'prompt',      'string', true ],
        [ 'group',       'string', true ]
      ].each do |pp_name, pp_type, pp_nullable|
        begin
          instance_variable_set "@#{ pp_name }", DataTypes.ensure_value_is_datatype( eval(pp_name), pp_type, pp_nullable )
        rescue DataTypes::TypeError => e
          raise ParameterDefinitionError, "#{ pp_name }: #{ e.message }"
        end
      end

      raise ParameterDefinitionError, "name cannot start with two underscores" if @name[/^__/]
      raise ParameterDefinitionError, "type #{type} unrecognized" unless DataTypes.supported?( @type )
      begin
        @default = DataTypes.ensure_value_is_datatype( default, type, true )
      rescue
        raise ParameterDefinitionError, "default value is not of correct type"
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
    
      flagged_parameter.value = value unless flagged_parameter.error
      return flagged_parameter
    end
    
    def to_hash
      Hash[ 
        [ 'name', 'description', 'type', 'required', 'default', 'prompt', 
          'group', 'warning', 'error', 'value'
        ].collect{ |pname| [ pname, send( pname.to_sym ) ]}
      ]
    end
  
    def self.all_errors( parameter_array )
      parameter_array.collect{ |p| "#{[ p.group, p.name ].compact.join(' ')}: #{ p.error }" if p.error }.compact
    end
  
    def self.all_warnings( parameter_array )
      parameter_array.collect{ |p| "#{[ p.group, p.name ].compact.join(' ')}: #{ p.warning }" if p.warning }.compact
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