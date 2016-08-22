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

require_relative "./base_configuration"

module Configh
  require 'securerandom'

  module Configurable
  
    module ClassMethods
    
      def defined_configurables
        constants
          .find_all{ |c| c[/CONFIGURED_MODULE_KEY_.*/] }
          .collect{ |c| const_get(c) if const_get(c) }
          .compact
          .flatten
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
    
      def use_static_config_values( candidate_static_values_hash)
        self::ConfigurationFactory.initialize_from_static_values( candidate_static_values_hash )
      end
    
      def use_named_config( *args )
        self::ConfigurationFactory.initialize_from_named_config( *args )
      end
      
      def validate( values_hash )
        self::ConfigurationFactory.validate( values_hash )
      end
    
    end
  
    def self.included(base)
  
      configurable_key = "CONFIGURED_MODULE_KEY_#{ SecureRandom.hex(5) }"
      base.const_set configurable_key, Array.new

      base.define_singleton_method( 'configured_by' ) { |config_class|
        # build the name of the custom configuration factory class for debugging purposes
        config_factory_class_name = "#{config_class.name[ /[^\:]*?$/ ]}FactoryFor#{ base.name.gsub(/::/,'')}"
  
        base.const_set config_factory_class_name, Class.new( config_class )
        base.send( :remove_const, 'ConfigurationFactory' ) if base.const_defined?( 'ConfigurationFactory', false )
        base.const_set 'ConfigurationFactory', base.const_get( config_factory_class_name )
        base::ConfigurationFactory.const_set 'CONFIGURED_CLASS', base
      }
    
      base.define_singleton_method( 'define_parameter' ) { |args|
        base.const_get( configurable_key ) << Parameter.new( group: base.name[ /[^\:]*?$/ ].downcase, **args )
      }
    
      base.define_singleton_method( 'define_group_validation_callback' ) { |args|
        base.const_get( configurable_key ) << GroupValidationCallback.new( group: base.name.downcase, **args )
      }
      
      if base.is_a?( Class ) and base.superclass&.const_defined? 'ConfigurationFactory'
        base.configured_by base.superclass.const_get( 'ConfigurationFactory').superclass
      else
        base.configured_by BaseConfiguration
      end
      
      base.extend ClassMethods
    
    end
  
    def use_static_config_values( candidate_static_values_hash )
      self.class::use_static_config_values( candidate_static_values_hash )
    end
    
    def use_named_config( args )
      self.class::use_named_config( args )
    end
  
  end
end
