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

  class ConstantDefinitionError < StandardError; end
  
  class Constant
    attr_accessor :name, :value, :group

    def initialize(name:, value:, group: nil)
      [['name', name, 'populated_string'],
       ['value', value, 'object', true],
       ['group', group, 'string', true]
      ].each do |pp_name, pp_value, pp_type, pp_nullable|
        begin
          instance_variable_set "@#{ pp_name }", DataTypes.ensure_value_is_datatype( pp_value, pp_type, pp_nullable )
        rescue DataTypes::TypeError => e
          raise ConstantDefinitionError, "#{ pp_name }: #{ e.message }"
        end
      end

      raise ConstantDefinitionError, "name cannot start with two underscores" if @name[/^__/]
    end
  end
end
