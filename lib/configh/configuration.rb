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
require_relative './group_test_callback'
require_relative './array_based_configuration'
require_relative './mongo_based_configuration'

module Configh
  
  class ConfigInitError < StandardError; end
  class ConfigValidationError < StandardError; end
  class ConfigRefreshError < StandardError; end
  class ConfigNotFoundError < StandardError; end
  class ConfigUnchangedWarning < StandardError; end
  class UnrecognizedTypeError < StandardError; end
  class UnsupportedStoreError < StandardError; end
    
  class Configuration
    attr_reader :__name, :__type, :__timestamp, :__values
  
    CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES = {
      Array   => ArrayBasedConfiguration,
      Mongo::Collection => MongoBasedConfiguration
    }
    
    def self.find_or_create( for_class, store, name, values_for_create: {}, maintain_history: false )
      
      config = find( for_class, store, name ) || 
               create( for_class, store, name, values_for_create, maintain_history: false )
    end
    
    def self.find( for_class, store, name, raw: false ) 
      
      config_class = CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES[ store.class ]
      raise( UnsupportedStoreError, "Configuration store must be one of #{ CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES.keys.join(', ')}" ) unless config_class

      new_config = config_class.new( for_class, store, name )
      result = nil
      begin
        if raw
          result = new_config.get
        else
          new_config.refresh
          result = new_config
        end
      rescue ConfigNotFoundError => e
        return nil
      end
      result
    end
    
    def self.create( for_class, store, name, values, maintain_history: false )
      
      config_class = CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES[ store.class ]
      raise( UnsupportedStoreError, "Configuration store must be one of #{ CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES.keys.join(', ')}" ) unless config_class

      new_config = config_class.new( for_class, store, name, maintain_history: maintain_history )
      begin
        new_config.reset_values_to( values )
        new_config.save
      rescue ConfigValidationError => e
        raise ConfigInitError, "Unable to create configuration #{for_class.name} #{name}: #{ e.message }"
      end     
      new_config
    end

    def self.find_all( for_class, store, include_descendants: false, raw: false )
      
      configuration_class = CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES[ store.class ]
      raise( UnsupportedStoreError, "Configuration store must be one of #{ CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES.keys.join(', ')}" ) unless configuration_class

      types_to_find = [ for_class ]
      if include_descendants
        stored_classes = configuration_class.get_all_types( store )
        types_to_find.concat stored_classes.select{ |klass| klass < for_class }
      end
      
      Enumerator.new do |yielder|
        configuration_class.get_config_names_of_types( store, types_to_find ).each do | configured_class, config_name |
          yielder << [ configured_class, configured_class.find_configuration( store, config_name, raw: raw ) ]
        end
      end
    end
        
    def initialize( for_class, store, name, maintain_history: false  )
      @__type      = for_class
      @__store     = store
      @__name      = name
      @__maintain_history = maintain_history
      @__values    = {}
      @__timestamp = nil
    end        
        
    def refresh
      
      serialized_config = get
      raise ConfigNotFoundError, "Type #{ @__type } #{ @__name } not found during refresh" unless serialized_config
      
      stored_config = Configuration.unserialize( serialized_config )
      return false if @__timestamp and stored_config[ 'timestamp' ] == @__timestamp
      raise ConfigRefreshError, "#{@__type} #{@__name} configuration in database is older than that previously loaded." if @__timestamp and stored_config['timestamp'] < @__timestamp
      
      reset_values_to( stored_config[ 'values' ] )
      @__timestamp = stored_config[ 'timestamp' ]
      @__maintain_history = stored_config[ 'maintain_history' ]
      return true 
          
    end
    
    def reset_values_to( candidate_values_hash, bypass_validation = false )
      
      validated_values_hash = candidate_values_hash
      
      unless bypass_validation
        flagged_parameters, validated_values_hash, errors, warnings = validate( candidate_values_hash )
        raise ConfigValidationError, errors.join(",") if errors.any?
      end
      
      @__values.each do | grp, _sub |
        singleton_class.class_eval{ remove_instance_variable "@#{grp}" if instance_variable_defined? "@#{grp}"}
      end
      
      @__values = validated_values_hash 
      
      @__type.defined_parameters.each do |p|
        singleton_class.class_eval { attr_reader p.group.to_sym }
        subobj = instance_variable_get("@#{p.group}" ) || instance_variable_set( "@#{p.group}", Object.new )  
        subobj.singleton_class.class_eval { attr_reader p.name.to_sym }
        subobj.singleton_class.class_eval { attr_reader p.name.to_sym }
        subobj.instance_variable_set "@#{p.name}", @__values[ p.group ][ p.name ]
      end    
    end
    
    def validate( values_hash )
    
      working_values_hash = Marshal.load( Marshal.dump( values_hash ))  # deep copy required
      flagged_configurables = [] 
      
      @__type.defined_parameters.each do |p|
        working_values_hash[ p.group ] ||= {}
        flagged_configurables << p.validate( working_values_hash[ p.group ][ p.name ])
      end
      errors   = Parameter.all_errors( flagged_configurables )
      warnings = Parameter.all_warnings( flagged_configurables )

      validated_values_hash = Parameter.to_values_hash( flagged_configurables) unless errors.any?
    
      if validated_values_hash and @__type.defined_group_validation_callbacks.any?
        candidate_config = self.class.new( @__type, [], 'temp' )
        candidate_config.reset_values_to( validated_values_hash, :secret_validation_bypass )
        @__type.defined_group_validation_callbacks.each do |vc|
          flagged_vc_configurable = vc.validate( candidate_config )
          errors << flagged_vc_configurable.error if flagged_vc_configurable.error
          flagged_configurables << flagged_vc_configurable
        end
      end      
    
      [ flagged_configurables, validated_values_hash, errors, warnings ]
    end  
    
    def test_and_return_errors
      
      errors = {}
      @__type.defined_group_test_callbacks.each do |cb|
        e = cb.test_and_return_error_string( self )
        errors[ cb.callback_method.to_s ] = e if e
      end
      errors
    end

    def serialize
      
      serialized_values = {}
      @__values.each do |grp, params|
        serialized_values[ grp ] ||= {}
        params.each do |k,v|
          unless v.nil?
            serialized_values[ grp ][ k ] = v.to_s
          end
        end
      end
      
      @__timestamp ||= Time.now.utc
      
      {
        'type'             => @__type.to_s,
        'name'             => @__name,
        'timestamp'        => @__timestamp.xmlschema(6),
        'maintain_history' => @__maintain_history.to_s,
        'values'           => serialized_values
      }
      
    end
    
    def Configuration.unserialize( serialized_config )
      
      begin
        type = eval( serialized_config[ 'type' ])
      rescue
        raise ConfigInitError, "Unrecognized type #{ serialized_values[ 'type' ]}"
      end
      
      serialized_values = serialized_config[ 'values' ]
      unserialized_values = {}
      serialized_values.each do |grp, params|
        unserialized_values[ grp ] ||= {}
        params.each do |k,v|
          target_datatype = type.defined_parameters.find{ |p| p.group == grp and p.name == k }.type
          unserialized_values[ grp ][k] = DataTypes.ensure_value_is_datatype( v, target_datatype )
        end
      end
      
      unserialized_config = {
        'type'             => type,
        'name'             => serialized_config[ 'name' ],
        'timestamp'        => Time.parse( serialized_config[ 'timestamp']),
        'maintain_history' => eval(serialized_config[ 'maintain_history' ]),
        'values'           => serialized_values       
      }
      
      unserialized_config
    end
    
    def dup_param_with_value( p )
      
      dupped = Marshal.load( Marshal.dump ( p ))
      dupped.value = @__values[ p.group ][ p.name ]
      dupped
    end
    
    def find_all_parameters
      found = []
      @__type.defined_parameters.each do |p,i|
        dupped = dup_param_with_value( p )
        found << dupped if yield( dupped )
      end
      found
    end
    
    def self.validate( for_class, candidate_values )
      
      temp_config = new( for_class, nil, 'temp' )
      flagged_configurables, values, errors, warnings = temp_config.validate( candidate_values )
      flagged_configurables.collect{ |cfgbl| cfgbl.to_hash }
    end     
  end
  
end


