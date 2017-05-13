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

require 'facets/kernel/constant'
require_relative './configuration'

module Configh
  
  class Configuration; end
    
  class ArrayBasedConfiguration < Configuration

    def self.get_config_names_of_types( array, types_to_find )
      array = array.collect{ |config|
          type = constant(config['type'])
          [ config[ 'type' ], config[ 'name' ] ] if types_to_find.include? type
      }
      array.compact!
      array.sort!
      array.uniq!
      array.collect!{ |t,n| [ constant(t), n ]}
      array
    end

    def self.get_all_types( array )
      begin
        all_types = array.collect{ |config| config[ 'type' ]}
        all_types.uniq!
        all_types.collect!{ |tname| constant(tname) }
      rescue
        raise ConfigInitError, "Unrecognized type #{ config[ 'type' ]}"
      end
      all_types
    end

    def self.name_exists?(for_class, array, name)
      array.index{ |config| config['type'] == for_class.to_s && /^#{name}$/i =~ config['name'] }
    end

    def self.each_raw_config( array )
      array.each { |i| yield i }
    end

    def self.load( array, config )
      array << config
    end

    def self.max_timestamp_for_types(array, types)
      array.collect{ |config| config['timestamp'] if types.include?(config['type']) }.compact.max
    end

    def get
     config = @__store
        .select{ |cfg| cfg[ 'type'] == @__type.to_s and cfg[ 'name' ] == @__name }
        .sort{ |a,b| b[ 'timestamp' ] <=> a[ 'timestamp' ]}
        .first
      
     config
    end
    
    def save
    
      trying_config = serialize

      unless @__maintain_history
        @__store.delete_if{ |cfg| cfg[ 'type' ] == @__type.to_s and cfg[ 'name' ] == @__name }
      end
      @__store << trying_config
      @__timestamp = Time.parse(trying_config[ 'timestamp' ])
    end
  
    def history
      
      configs = @__store
        .select{ |cfg| cfg[ 'type' ] == @__type.to_s and cfg[ 'name' ] == @__name }
        .sort{ |a,b| a[ 'timestamp' ] <=> b[ 'timestamp'] }
      configs.collect{ |c| c['values'].merge( '__timestamp' => c['timestamp']) }
    end  

  end 
end