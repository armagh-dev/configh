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

require 'mongo'
require 'facets/kernel/constant'

require_relative './configuration'

module Configh
    
  class Configuration; end
  class MongoBasedConfiguration < Configuration
    
    def self.get_config_names_of_types( collection, types_to_find )

      typenames_to_find = types_to_find.collect{ |t| t.name }
      names_and_types = collection.find( { 'type' => { '$in' => typenames_to_find }}, { 'name':1, 'type': 1}).to_a
      names_and_types.collect!{ |h| 
        begin
         nat = [ h['type'], h['name']]
       rescue
         raise ConfigInitError, "Unrecognized type #{h['type']}"
       end
       nat
      }.uniq!
      names_and_types.collect{ |t,n| [ constant(t), n ]}
    end

    def self.get_all_types( collection )
      collection.distinct( 'type' ).collect{ |k| 
        begin
          t = constant(k)
        rescue
          raise ConfigInitError, "Unrecognized type #{k}"
        end
        t
      }
    end

    def self.name_exists?( for_class, collection, name )
      collection.find( { 'type' => for_class.to_s, 'name' => { '$regex' => /^#{name}$/i }} ).count > 0
    end


    def self.each_raw_config( collection )
      collection.find(nil,{'projection'=>{'_id'=>0}}).each { |item| yield item}
    end

    def self.load( collection, config )
      collection.insert_one config
    end

    def self.max_timestamp_for_types( collection, types)

      result = collection.aggregate( [
          { '$match' => { 'type' => { '$in' => types }}},
          { '$group' => { '_id' => 'max_timestamp', 'max_timestamp': { '$max' => '$timestamp'}}}
      ]).first

      result.nil? ? nil : result[ 'max_timestamp' ]
    rescue => e
      raise e.class, "Problem getting max config timestamp: #{ e.message }"
    end
         
    def get
      begin
        type_name = @__type.name
        serialized_config_in_db = @__store.aggregate( [
           { '$match' => { 'type' => type_name, 'name' => @__name } },
           { '$sort'  => { 'timestamp' => -1 }},
           { '$limit' => 1 }
         ]).first
      rescue => e
        raise e.class, "Problem pulling #{ @__type } configuration '#{@__name}' from database: #{ e.message }"
      end
      
      serialized_config_in_db
    end
    
    def save
      
      trying_config = serialize
      
      begin
        if @__maintain_history
          @__store.insert_one trying_config
        else
          @__store.find_one_and_replace( { 'type' => trying_config['type'], 'name' => @__name }, trying_config, :upsert => true)
        end
      rescue => e   
        raise e.class, "Problem saving #{ @__type.name } configuration '#{ @__name}' to database: #{ e.message }"
      end
      @__timestamp = Time.parse(trying_config[ 'timestamp' ])

    end
  
    def history
      begin
        type_name = @__type.name
        configs = @__store.aggregate( [
           { '$match' => { 'type' => type_name, 'name' => @__name } },
           { '$sort'  => { 'timestamp' => 1 }}
         ]).to_a
      rescue => e
        raise e.class, "Problem pulling #{ @__type } configuration history '#{@__name}' from database: #{ e.message }"
      end
      configs.collect{ |c| c['values'].merge( '__timestamp' => c['timestamp']) }
    end  

  end 
end
