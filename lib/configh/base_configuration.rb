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

require_relative './parameter'
require_relative './group_validation_callback'

module Configh
  
  class ConfigInitError < StandardError; end
  class ConfigValidationError < StandardError; end
  class ConfigRefreshError < StandardError; end
  class ConfigNotFoundError < StandardError; end
  class ConfigUnchangedWarning < StandardError; end
    
  class BaseConfiguration
  
    def self.initialize_from_static_values( values_hash )
      bc = new( nil )
      bc.reset_values_to( values_hash )
      bc
    end
  
    def self.initialize_from_named_config( *args )
      raise ConfigInitError, "BaseConfiguration class does not support named configurations."
    end
    
    def self.validate( values_hash )
    
      working_values_hash = Marshal.load( Marshal.dump( values_hash ))  # deep copy required
      flagged_configurables = [] 
      
      # Validate parameters one at a time
      self::CONFIGURED_CLASS.defined_parameters.each do |p|
        working_values_hash[ p.group ] ||= {}
        flagged_configurables << p.validate( working_values_hash[ p.group ][ p.name ])
      end
      errors   = Parameter.all_errors( flagged_configurables )
      warnings = Parameter.all_warnings( flagged_configurables )
  
      # Call group validations if there are any.  We have to build a bogus config object for that.
      validated_values_hash = Parameter.to_values_hash( flagged_configurables) unless errors.any?
    
      if validated_values_hash and self::CONFIGURED_CLASS.defined_group_validation_callbacks.any?
        candidate_config = new( nil )
        candidate_config.reset_values_to( validated_values_hash, :secret_validation_bypass )
        self::CONFIGURED_CLASS.defined_group_validation_callbacks.each do |vc|
          flagged_vc_configurable = vc.validate( candidate_config )
          errors << flagged_vc_configurable.error if flagged_vc_configurable.error
          flagged_configurables << flagged_vc_configurable
        end
      end      
    
      [ flagged_configurables, validated_values_hash, errors, warnings ]
    end  
    
    def self.detailed_validation( candidate_values )
      flagged_configurables, values, errors, warnings = validate( candidate_values )
      flagged_configurables.collect{ |cfgbl| cfgbl.to_hash }
    end     

    def initialize( config_name )
      @__timestamp = nil
      @__type      = self.class.const_get( 'CONFIGURED_CLASS' ).name[/[^:]*?$/]
      @__values    = {}
      @__config_name = config_name
      @__static    = true
    end            
  
    def change_value( pgroup, pname, value )
      candidate_values_hash = Marshal.load( Marshal.dump( @__values ))  #deep copy
      candidate_values_hash[ pgroup ][ pname ] = value
      reset_values_to( candidate_values_hash )
      save  
    end
    
    def replace_values( candidate_values )
      reset_values_to( candidate_values )
      save
    end
           
    def get
      raise ConfigInitError, "BaseConfiguration class does not support persisted configurations."
    end
    
    def save
    end
    
    def refresh
      false
    end
    
    def reset_values_to( candidate_values_hash, bypass_validation = false )
      
      validated_values_hash = candidate_values_hash
      
      unless bypass_validation
        flagged_parameters, validated_values_hash, errors, warnings = self.class.validate( candidate_values_hash )
        raise ConfigValidationError, errors.join(",") if errors.any?
      end
      
      @__values.each do | grp, _sub |
        singleton_class.class_eval{ remove_instance_variable "@#{grp}" if instance_variable_defined? "@#{grp}"}
      end
      
      @__values = validated_values_hash 
      
      self.class::CONFIGURED_CLASS.defined_parameters.each do |p|
        singleton_class.class_eval { attr_reader p.group.to_sym }
        subobj = instance_variable_get("@#{p.group}" ) || instance_variable_set( "@#{p.group}", Object.new )  
        subobj.singleton_class.class_eval { attr_reader p.name.to_sym }
        subobj.singleton_class.class_eval { attr_reader p.name.to_sym }
        subobj.instance_variable_set "@#{p.name}", @__values[ p.group ][ p.name ]
        config = self
        if p.writable
          subobj.define_singleton_method( "#{p.name}=" ) { |v| config.change_value( p.group, p.name, v ) } 
        end
      end    
    end
    
    def dup_param_with_value( p )
      
      dupped = Marshal.load( Marshal.dump ( p ))
      dupped.value = @__values[ p.group ][ p.name ]
      dupped
    end
    
    def find_all
      
      found = []
      self.class::CONFIGURED_CLASS.defined_parameters.each do |p,i|
        dupped = dup_param_with_value( p )
        found << dupped if yield( dupped )
      end
      found
    end
        
    
  end
  
  class PersistedConfiguration < BaseConfiguration
    
    def self.initialize_from_named_config( *args )
      bc = new( *args )
      bc.load_named_config
      bc
    end
    
    def load_named_config
      
      begin
        @__static = false
        refresh
        
      rescue ConfigValidationError => e
        raise ConfigInitError, "#{@__type} configuration in database is invalid: #{e.message.join("\n")}."
      
      rescue ConfigNotFoundError => e
        begin
          reset_values_to( {} )
          save
        rescue ConfigValidationError => e
          raise ConfigInitError, "No #{@__type} configuration found named #{@__config_name} and unable to create from defaults: #{ e.message }"
        end     
      end    
    end
    
    def refresh

      return false if @__static
      
      retrieved_values, timestamp = get
      raise ConfigNotFoundError unless retrieved_values
      return false if @__timestamp and timestamp == @__timestamp
      raise ConfigRefreshError, "#{@__type} configuration in database is older than that previously loaded." if @__timestamp and timestamp < @__timestamp
      
      reset_values_to( retrieved_values )
      @__timestamp = timestamp
      return true 
          
    end
  end
    
end
