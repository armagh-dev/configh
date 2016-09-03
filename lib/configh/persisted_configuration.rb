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

require_relative './base_configuration.rb'

module Configh
      
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
          raise ConfigInitError, "No #{@__type} configuration found named #{@__name} and unable to create from defaults: #{ e.message }"
        end     
      end    
    end
    
    def refresh

      return false if @__static
      
      retrieved_values, timestamp = get
      raise ConfigNotFoundError unless retrieved_values
      return false if @__timestamp and timestamp == @__timestamp
      raise ConfigRefreshError, "#{@__type} #{@__name} configuration in database is older than that previously loaded." if @__timestamp and timestamp < @__timestamp
      
      reset_values_to( retrieved_values )
      @__timestamp = timestamp
      return true 
          
    end
  end
    
end
