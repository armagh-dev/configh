# Copyright 2018 Noragh Analytics, Inc.
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

require_relative 'configuration'

require 'facets/kernel/deep_copy'
require 'facets/string/snakecase'
require 'securerandom'

module Configh

  module Configurable
  
    module ClassMethods
    
      def defined_configurables
        
        configs = constants
          .find_all{ |c| c[/CONFIGH_PARAMS_.*/] }
          .collect{ |c| const_get(c) if const_get(c) }
          
        klass_configs, module_configs = configs.partition{ |h| h[ :klass ].is_a? Class }
        klass_configs.sort!{ |a,b| ( a == b ) ? 0 : ( (a<b) ? -1 : 1 ) }
        module_configs.each do |mc|
          i = klass_configs.index{ |kc| kc[ :klass ].included_modules.include?( mc[ :klass ] )} || 0
          klass_configs.insert( i, mc )
        end
        
        params = {}
        undefined_params = {}

        klass_configs.each do |config|
          p = config[:params]
          up = config[:undefined_params]

          p.each do |group, pig|
            params[ group ] ||= {}
            params[ group ].merge! pig
          end

          up.each do |group, params|
            undefined_params[ group ] ||= []
            undefined_params[ group ].concat params
          end
        end

        params.each do |g, p|
          p_names = p.keys
          p_names.each do |name|
            params[g].delete(name) if undefined_params[g]&.include?(name)
            params.delete(g) if params[g].empty?
          end
        end

        params = params.collect{ |group,pig| pig.values }.flatten
        params.deep_copy
      end
    
      def defined_parameters
        defined_configurables.find_all{ |p| p.is_a? Parameter }
      end

      def defined_constants
        defined_configurables.find_all{ |p| p.is_a? Constant }
      end
    
      def required_parameters
        defined_parameters.each_with_index.find_all{ |p,i| p.required }
      end
    
      def parameters_with_defaults
        defined_parameters.each_with_index.find_all{ |p,i| p.default }
      end
    
      def defined_group_validation_callbacks
        defined_configurables.find_all{ |vc| vc.is_a? GroupValidationCallback }
      end
      
      def defined_group_test_callbacks
        defined_configurables.find_all{ |vc| vc.is_a? GroupTestCallback }
      end
    
      def find_or_create_configuration( store, name, values_for_create: nil, maintain_history: false )
        Configh::Configuration.find_or_create( self, store, name, values_for_create: values_for_create, maintain_history: maintain_history )
      end
      
      def find_configuration( store, name, raw: false, bypass_validation: false )
        Configh::Configuration.find( self, store, name, raw: raw, bypass_validation: bypass_validation )
      end
      
      def create_configuration( store, name, values, maintain_history: false, bypass_validation: false, test_callback_group: nil )
        Configh::Configuration.create( self, store, name, values, maintain_history: maintain_history, bypass_validation: bypass_validation, test_callback_group: test_callback_group )
      end

      def force_update_configuration( store, name, new_values, maintain_history: false, bypass_validation: false )
        Configh::Configuration.create( self, store, name, new_values, maintain_history: maintain_history, updating: true, bypass_validation: bypass_validation )
      end
      
      def find_all_configurations( store, include_descendants: false, raw: false )
        Configh::Configuration.find_all( self, store, include_descendants: include_descendants, raw: raw )
      end

      def max_timestamp( store )
        Configh::Configuration.max_timestamp( self, store )
      end
            
      def validate( values_hash )
        Configh::Configuration.validate( self, values_hash )
      end

      def edit_configuration( values_hash )
        params_hash = {}
        params_hash['parameters'] = Configh::Configuration.validate( self, values_hash )
        params_hash[ 'type' ] = self
        params_hash
      end

      def configuration_values_valid?( values_hash )
        Configh::Configuration.valid?( self, values_hash )
      end
    end
  
    def self.included(base)
  
      configurable_key = "CONFIGH_PARAMS_#{ SecureRandom.hex(5) }"
      base.const_set configurable_key, { :klass => base, :params => {}, :undefined_params => {}}

      base.define_singleton_method( 'define_parameter' ) { |args|
        params_hash = base.const_get( configurable_key )[ :params ]
        group = args[ :group ] || base.name[ /[^\:]*?$/ ].snakecase
        params_hash[ group ] ||= {}
        params_hash[ group ][ args[:name] ] = Parameter.new( group: group, **args )
      }

      base.define_singleton_method( 'define_constant' ) { |args|
        params_hash = base.const_get( configurable_key )[ :params ]
        group = args[ :group ] || base.name[ /[^\:]*?$/ ].snakecase
        params_hash[ group ] ||= {}
        params_hash[ group ][ args[:name] ] = Constant.new( group: group, **args)
      }

      base.define_singleton_method('undefine_parameter') { |args|
        undefined_params_hash = base.const_get( configurable_key )[ :undefined_params ]
        group = args[ :group ] || base.name[ /[^\:]*?$/ ].snakecase
        undefined_params_hash[ group ] ||= []
        undefined_params_hash[ group ] << args[:name]
      }

      base.define_singleton_method( 'define_group_validation_callback' ) { |args|
        params_hash = base.const_get( configurable_key )[ :params ]
        group = args[ :group ] || base.name[ /[^\:]*?$/ ].snakecase
        name = args[:name] || "vc_" + args[:callback_method].to_s
        params_hash[ group ] ||= {}
        params_hash[ group ][ name ] = GroupValidationCallback.new( group: group, **args )
      }
      
      base.define_singleton_method( 'define_group_test_callback' ) { |args|
        params_hash = base.const_get( configurable_key )[ :params ]
        group = args[ :group ] || base.name[ /[^\:]*?$/ ].snakecase
        name = args[:name] || "tc_" + args[:callback_method].to_s
        params_hash[ group ] ||= {}
        params_hash[ group ][ name ] = GroupTestCallback.new( group: group, **args )
      }
            
      base.extend ClassMethods
    
    end
    
  end
end

