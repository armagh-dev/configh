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

module Configh

  CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES = {
      Array => ArrayBasedConfiguration,
      Mongo::Collection => MongoBasedConfiguration
  }

  class UnsupportedStoreError < StandardError; end

  class ConfigStore

    def self.configuration_class( store )
      config_class = CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES[ store.class ]
      raise( UnsupportedStoreError, "Configuration store must be one of #{ CONFIGURATION_CLASSES_FOR_SUPPORTED_STORES.keys.join(', ')}" ) unless config_class
      config_class
    end

    def self.copy_contents_without_validation( from_store, to_store, names: nil )

      from_class = configuration_class( from_store )
      to_class = configuration_class( to_store )
      from_class.each_raw_config( from_store ) do |raw_config|
        to_class.load( to_store, raw_config ) unless names && !names.include?( raw_config['name'])
      end
    end
  end


end