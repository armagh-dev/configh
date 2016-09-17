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

require_relative './configuration'

module Configh
  
  class Configuration; end
    
  class ArrayBasedConfiguration < Configuration
    
    def self.get_config_names_of_types( array, types_to_find )
     array
        .collect{ |config| 
          type = eval(config['type'])
          [ config[ 'type' ], config[ 'name' ] ] if types_to_find.include? type 
        }.compact
        .sort
        .uniq
        .collect{ |t,n| [ eval(t), n ]}
    end

    def self.get_all_types( array )
      all_types = []
      begin
        all_types = array
          .collect{ |config| config[ 'type' ]}
          .uniq
          .collect{ |tname| eval(tname) }
      rescue
        raise ConfigInitError, "Unrecognized type #{ config[ 'type' ]}"
      end
      all_types
    end
         
    def get
     config = @__store
        .select{ |cfg| cfg[ 'type'] == @__type.to_s and cfg[ 'name' ] == @__name }
        .sort{ |a,b| b[ 'timestamp' ] <=> a[ 'timestamp' ]}
        .first
      
     config
    end
    
    def save
    
      trying_timestamp = Time.now.utc.round
        
      trying_config = serialize
      trying_config[ 'timestamp' ] = trying_timestamp.to_s
      
      unless @__maintain_history
        @__store.delete_if{ |cfg| cfg[ 'type' ] == @__type.to_s and cfg[ 'name' ] == @__name }
      end
      @__store << trying_config
      @__timestamp = trying_timestamp
    end
  
    def history
      
      configs = @__store
        .select{ |cfg| cfg[ 'type' ] == @__type.to_s and cfg[ 'name' ] == @__name }
        .sort{ |a,b| a[ 'timestamp' ] <=> b[ 'timestamp'] }
      configs.collect{ |c| [ c['timestamp'], c['values'] ]}
    end  
    
    def detailed_history
      begin
        historical_configs = history
        historical_configs.collect{ |ts,v| [ ts, @__type.validate( v )]}
      end
    end
  end 
end