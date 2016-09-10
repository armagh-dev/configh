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

require_relative "./configuration"

module Configh
  require 'securerandom'

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
        klass_configs.collect{ |h| h[:params]}.each do |h|
          h.each do |group, pig|
            params[ group ] ||= {}
            params[ group ].merge! pig 
          end
        end
        params = params.collect{ |group,pig| pig.values }.flatten
        Marshal.load( Marshal.dump( params ))
      end
    
      def defined_parameters
        defined_configurables.find_all{ |p| p.is_a? Parameter }
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
    
      def find_or_create_configuration( store, name, values_for_create: nil, maintain_history: false )
        Configh::Configuration.find_or_create( self, store, name, values_for_create: values_for_create, maintain_history: maintain_history )
      end
      
      def find_configuration( store, name )
        Configh::Configuration.find( self, store, name )
      end
      
      def create_configuration( store, name, values, maintain_history: false )
        Configh::Configuration.create( self, store, name, values, maintain_history: maintain_history )
      end
      
      def find_all_configurations( store, include_descendants: false )
        Configh::Configuration.find_all( self, store, include_descendants: include_descendants )
      end
      
      def validate( values_hash )
        Configh::Configuration.validate( self, values_hash )
      end
    
    end
  
    def self.included(base)
  
      configurable_key = "CONFIGH_PARAMS_#{ SecureRandom.hex(5) }"
      base.const_set configurable_key, { :klass => base, :params => {}}

      base.define_singleton_method( 'define_parameter' ) { |args|
        params_hash = base.const_get( configurable_key )[ :params ]
        group = args[ :group ] || base.name[ /[^\:]*?$/ ].downcase
        params_hash[ group ] ||= {}
        params_hash[ group ][ args[:name] ] = Parameter.new( group: group, **args )
      }
    
      base.define_singleton_method( 'define_group_validation_callback' ) { |args|
        params_hash = base.const_get( configurable_key )[ :params ]
        group = args[ :group ] || base.name.downcase
        params_hash[ group ] ||= {}
        params_hash[ group ][ args[:name]] = GroupValidationCallback.new( group: group, **args )
      }
            
      base.extend ClassMethods
    
    end
    
  end
end
