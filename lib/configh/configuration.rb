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

require 'ice_nine'
require 'hash_diff'
require 'json'
require 'facets/kernel/constant'
require 'facets/kernel/deep_copy'

require_relative './constant'
require_relative './parameter'
require_relative './group_validation_callback'
require_relative './group_test_callback'
require_relative './array_based_configuration'
require_relative './mongo_based_configuration'
require_relative './config_store'

module Configh
  
  class ConfigInitError < StandardError; end
  class ConfigValidationError < StandardError; end
  class ConfigRefreshError < StandardError; end
  class ConfigNotFoundError < StandardError; end
  class ConfigUnchangedWarning < StandardError; end
  class UnrecognizedTypeError < StandardError; end

  class Configuration
    attr_reader :__name, :__type, :__timestamp, :__values, :__maintain_history
  

    def self.find_or_create( for_class, store, name, values_for_create: {}, maintain_history: false )
      find( for_class, store, name ) || create( for_class, store, name, values_for_create, maintain_history: maintain_history )
    end
    
    def self.find( for_class, store, name, raw: false, bypass_validation: false )

      config_class = ConfigStore.configuration_class( store )
      new_config = config_class.new( for_class, store, name )
      result = nil
      begin
        if raw
          result = new_config.get
        else
          new_config.refresh( bypass_validation: bypass_validation )
          result = new_config
        end
      rescue ConfigNotFoundError
        return nil
      end
      result
    end

    def self.create( for_class, store, name, values, maintain_history: false, updating: false, bypass_validation: false, test_callback_group: nil )

      config_class = ConfigStore.configuration_class( store )
      raise(ConfigInitError, "Name already in use") if config_class.name_exists?(for_class, store, name) && !updating
      raise(ConfigInitError, "Values must be a hash" ) unless values.is_a?(Hash)

      new_config = config_class.new(for_class, store, name, maintain_history: maintain_history)
      begin
        new_config.reset_values_to(values, bypass_validation, test_callback_group: test_callback_group)
        new_config.save
      rescue ConfigValidationError => e
        raise ConfigInitError, "Unable to create configuration for '#{for_class.name}' named '#{name}' because: #{ e.message }"
      end     
      new_config
    end

    def self.find_all( for_class, store, include_descendants: false, raw: false )

      configuration_class = ConfigStore.configuration_class( store )
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

    def self.max_timestamp( for_class, store )

      configuration_class = ConfigStore.configuration_class(store)
      types_to_find = [ for_class ]
      stored_classes = configuration_class.get_all_types( store )
      types_to_find.concat stored_classes.select{ |klass| klass < for_class }
      types_to_find.collect!(&:to_s)
      configuration_class.max_timestamp_for_types( store, types_to_find )
    end
        
    def initialize( for_class, store, name, maintain_history: false  )
      @__type      = for_class
      @__store     = store
      @__name      = name
      @__maintain_history = maintain_history
      @__values    = {}
      @__timestamp = nil
    end        
        
    def refresh( bypass_validation: false )
      serialized_config = get
      raise ConfigNotFoundError, "Type #{ @__type } #{ @__name } not found during refresh" unless serialized_config
      stored_config = Configuration.unserialize( serialized_config, bypass_validation: bypass_validation )
      return false if @__timestamp and stored_config[ 'timestamp' ] == @__timestamp
      raise ConfigRefreshError, "#{@__type} #{@__name} configuration in database is older than that previously loaded." if @__timestamp and stored_config['timestamp'] < @__timestamp
      reset_values_to( stored_config[ 'values' ], bypass_validation )
      @__timestamp = stored_config[ 'timestamp' ]
      @__maintain_history = stored_config[ 'maintain_history' ]
      return true 
    end

    def update_merge( values_to_merge, bypass_validation: false )

      raise ConfigInitError, "Values to merge must be a Hash" unless values_to_merge.is_a?(Hash)

      new_values = duplicate_values
      values_to_merge.each do |grp,params|
        new_values[grp] ||= {}
        new_values[grp].merge! params
      end
      update_replace( new_values, bypass_validation: bypass_validation )
    end

    def update_replace( new_values, bypass_validation: false )

      raise ConfigInitError, "New values must be a Hash" unless new_values.is_a?(Hash)

      reset_values_to( new_values, bypass_validation )
      @__timestamp = nil

      if @__maintain_history
        self.class.create( @__type, @__store, @__name, new_values, maintain_history: @__maintain_history, updating:true, bypass_validation: bypass_validation )
      else
        save
      end
    end
    
    def reset_values_to( candidate_values_hash, bypass_validation = false, test_callback_group: nil )
      
      validated_values_hash = candidate_values_hash
      
      unless bypass_validation
        _flagged_parameters, validated_values_hash, errors, _warnings =
          validate( candidate_values_hash, test_callback_group: test_callback_group )
        raise ConfigValidationError, "\n    " + errors.join("\n    ") if errors.any? && test_callback_group.nil?
      end
      
      @__values.each do | grp, _sub |
        singleton_class.class_eval { remove_instance_variable "@#{grp}" if instance_variable_defined? "@#{grp}"}
      end

      @__values = IceNine.deep_freeze validated_values_hash

      @__type.defined_parameters.each do |p|
        next unless test_callback_group.nil? || p.group == test_callback_group
        singleton_class.class_eval { attr_reader p.group.to_sym }
        subobj = instance_variable_get("@#{p.group}" ) || instance_variable_set( "@#{p.group}", Object.new )  
        subobj.singleton_class.class_eval { attr_reader p.name.to_sym }
        subobj.singleton_class.class_eval { attr_reader p.name.to_sym }
        subobj.instance_variable_set "@#{p.name}", @__values[ p.group ][ p.name ]
      end

      @__type.defined_constants.each do |c|
        next unless test_callback_group.nil? || c.group == test_callback_group
        singleton_class.class_eval { attr_reader c.group.to_sym }
        subobj = instance_variable_get("@#{c.group}" ) || instance_variable_set( "@#{c.group}", Object.new )
        subobj.singleton_class.class_eval { attr_reader c.name.to_sym }
        subobj.singleton_class.class_eval { attr_reader c.name.to_sym }
        subobj.instance_variable_set "@#{c.name}", c.value
      end
    end
    
    def validate( values_hash, test_callback_group: nil )
    
      working_values_hash = values_hash.deep_copy  # deep copy required
      flagged_configurables = [] 
      
      @__type.defined_parameters.each do |p|
        next unless test_callback_group.nil? || p.group == test_callback_group
        working_values_hash[ p.group ] ||= {}
        flagged_configurables << p.validate( working_values_hash[ p.group ][ p.name ])
        working_values_hash[ p.group ].delete p.name
      end

      working_values_hash.each do |group,params|
        next unless test_callback_group.nil? || group == test_callback_group
        if params.is_a?(Hash)
          params.each do |name,value|
             p = Parameter.new( group: group, name: name, type: 'string', description: 'non-existent')
             p.value = value
             p.error = 'Configuration provided for parameter that does not exist'
             flagged_configurables << p
          end
        end
      end

      errors   = Parameter.all_errors( flagged_configurables )
      warnings = Parameter.all_warnings( flagged_configurables )

      validated_values_hash = Parameter.to_values_hash( flagged_configurables ) unless errors.any? && test_callback_group.nil?
    
      if test_callback_group.nil? and validated_values_hash and @__type.defined_group_validation_callbacks.any?
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

    def serialized_values

      s_values = {}
      @__values.each do |grp, params|
        s_values[grp] ||= {}
        params.each do |k, v|
          unless v.nil?
            value = v.is_a?(Enumerable) ? v.to_json : v.to_s
            s_values[grp][k] = value
          end
        end
      end
      s_values
    end


    def serialize
      
      @__timestamp ||= Time.now.utc
      
      {
        'type'             => @__type.to_s,
        'name'             => @__name,
        'timestamp'        => @__timestamp.xmlschema(6),
        'maintain_history' => @__maintain_history.to_s,
        'values'           => serialized_values
      }
      
    end

    def Configuration.unserialized_values( param_defs, serialized_values, bypass_validation: false )
      un_values = {}
      serialized_values.each do |grp, params|
        un_values[ grp ] ||= {}
        params.each do |k,v|
          target_datatype = get_target_datatype(param_defs, grp, k)
          if target_datatype
            begin
              un_values[grp][k] = DataTypes.ensure_value_is_datatype( v, target_datatype )
            rescue
              un_values[grp][k] = v
              raise unless bypass_validation
            end
          else
            raise ConfigInitError, "Invalid and/or Unsupported Configuration for Group: #{grp.inspect} Parameters: #{params.inspect} Key: #{k.inspect} Value: #{v.inspect}" unless bypass_validation
          end
        end
      end
      un_values
    end

    def Configuration.unserialize( serialized_config, bypass_validation: false )
      begin
        type = constant( serialized_config[ 'type' ])
      rescue
        if bypass_validation
          type = serialized_config[ 'type' ]
        else
          raise ConfigInitError, "Unrecognized type #{ serialized_config[ 'type' ]}"
        end
      end

      unserialized_config = {
        'type'             => type,
        'name'             => serialized_config[ 'name' ],
        'timestamp'        => Time.parse( serialized_config[ 'timestamp']),
        'maintain_history' => JSON.parse(serialized_config[ 'maintain_history' ]),
        'values'           => unserialized_values( type.defined_parameters, serialized_config[ 'values'], bypass_validation: bypass_validation )
      }
      
      unserialized_config
    end

    def duplicate_values
      Configuration.unserialized_values( @__type.defined_parameters, serialized_values )
    end

    def dup_param_with_value( p )
      
      dupped = p.deep_copy
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
      flagged_configurables, _values, _errors, _warnings = temp_config.validate( candidate_values )
      flagged_configurables
          .collect{ |cfgbl| cfgbl.to_hash }
    end

    def self.valid?( for_class, candidate_values )

      flagged = validate( for_class, candidate_values )
      flagged.select{ |f| f['error'] }.length == 0
    end

    def self.get_target_datatype(params, group, name)
      find_group_and_name = params.find{ |p| p.group == group and p.name == name }
      find_group_and_name ? find_group_and_name.type : nil
    end

    def change_history
      changes = []
      all_configs = history
      num_changes = all_configs.length - 1
      num_changes.times do |i|
        comp = HashDiff::Comparison.new( all_configs[ i+1 ], all_configs[ i ])
        comp.diff.each do |grp,params|
          unless grp == '__timestamp'
            params.each do |param_key, values|
              changes << { 'at' => all_configs[i]['__timestamp'],
                           'param' => "#{grp} parameter #{param_key}",
                           'became' => values.first,
                           'was' => values.last
              }
            end
          end
        end
      end
      changes
    end
  end
end
