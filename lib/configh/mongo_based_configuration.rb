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

require 'mongo'

require_relative './configuration'

module Configh
    
  class Configuration; end
  class MongoBasedConfiguration < Configuration
    
    def self.get_config_names_of_types( collection, types_to_find )

      typenames_to_find = types_to_find.collect{ |t| t.name }
      names_and_types = collection.find( { 'type' => { '$in' => typenames_to_find }}, { 'name':1, 'type': 1}).to_a
      names_and_types.collect!{ |h| [ eval(h['type']), h['name']]}
      names_and_types
    end

    def self.get_all_types( collection )
      collection.distinct( 'type' ).collect{ |k| eval(k) }
    end
         
    def get
      begin
        type_name = @__type.name
        config_in_db = @__store.aggregate( [
           { '$match' => { 'type' => type_name, 'name' => @__name } },
           { '$sort'  => { 'timestamp' => -1 }},
           { '$limit' => 1 }
         ]).first
      rescue => e
        raise e.class, "Problem pulling #{ @__type } configuration '#{@__name}' from database: #{ e.message }"
      end
      
      config_in_db[ 'type' ] = eval( config_in_db[ 'type' ]) if config_in_db
      config_in_db
    end
    
    def save
      
      trying_config = to_hash
      trying_config[ 'timestamp' ] = Time.now.round
      type_name = @__type.name
      trying_config[ 'type' ] = type_name
            
      begin
        if @__maintain_history
          @__store.insert_one trying_config
        else
          @__store.find_one_and_replace( { 'type' => type_name, 'name' => @__name }, trying_config, :upsert => true)
        end
      rescue => e   
        raise e.class, "Problem saving #{ @__type.name } configuration '#{ @__name}' to database: #{ e.message }"
      end
      @__timestamp = trying_config[ 'timestamp' ]

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
      configs.collect{ |c| [ c['timestamp'], c['values'] ]}
    end  
    
    def detailed_history
      begin
        historical_configs = history
        historical_configs.collect{ |ts,v| [ ts, self.detailed_validation( v )]}
      end
    end
  end 
end