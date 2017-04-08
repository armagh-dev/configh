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

require_relative '../helpers/coverage_helper'

require_relative '../../lib/configh/configuration'
require_relative '../../lib/configh/configurable'
require 'mongo'

require 'test/unit'
require 'mocha/test_unit'

class TestIntegConfigStore < Test::Unit::TestCase

  class << self

    def startup
      begin
        try_start_mongo
        try_connect
        @@collection = @@connection[ 'config' ]
        @@collection.drop
      rescue
        puts "unable to start mongo"
        exit
      end
    end

    def try_start_mongo
      @@pid = nil
      psline = `ps -ef | grep mongod | grep -v grep`
      if psline.empty?
        puts "trying to start mongod..."
        @@pid = spawn 'mongod 1>/dev/null 2>&1'
        sleep 5
      else
        puts "mongod was running at entry.  will be left running"
        return
      end
      Process.detach @@pid
      raise if `ps -ef | grep mongod | grep -v grep`.empty?
      puts "mongod successfully started."

    end

    def try_connect
      Mongo::Logger.logger.level = ::Logger::FATAL
      @@connection = Mongo::Client.new(
          [ '127.0.0.1:27017' ],
          :database=>'test_integ_mongo_based_config',
          :server_selection_timeout => 5,
          :connect_timeout => 5
      )
      @@connection.collections
    end

    def shutdown
      if @@pid
        puts "\nshutting down mongod"
        `kill \`pgrep mongod\``
      end
      sleep 5
    end
  end

  def setup
    @@collection.drop
    @defined_modules_and_classes = []
  end
  
  def teardown
    Object.module_eval "
      %w{ #{@defined_modules_and_classes.join(" ")} }.each do |c|
        remove_const c if const_defined? c
      end"
  end
  
  def setup_simple_configured_class

    d = Date.today
    bogus_class = new_configurable_class 'Bogus'
    bogus_class.define_singleton_method('bogus_validate'){ |config| }
    bogus_class.define_singleton_method('bogus_test'){ |config| }
    klass = new_configurable_class 'Simple'
    klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
    klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
    klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d
    klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus_validate
    klass.define_group_test_callback       callback_class: Bogus, callback_method: :bogus_test
    klass
  end
  
  def setup_simple_configured_module
    d = Date.today
    mod = new_configurable_module 'Green'
    mod.define_parameter name: 'custom_hue', description: 'shade of green', type: 'string', required: false, default: 'lime'
    mod.define_parameter name: 'rgb', description: 'rgb value', type: 'string', required: false
    mod.define_parameter name: 'web', description: 'web standard color', type: 'boolean', required:true
    mod.define_singleton_method('good_green') { |candidate_config|
      error = nil
      if candidate_config.green.web
        error = 'must provide an RGB value for web colors' if candidate_config.green.rgb.nil?
      else
        allowed_custom_hues = %w(lime pea neon olive)
        h = candidate_config.green.custom_hue
        error = "hue #{h} not one of allowed values: #{allowed_custom_hues.join(", ")}" unless allowed_custom_hues.include?( h )
      end
      error
    }
    mod.define_singleton_method( 'try_green' ) { |candidate_config|
      candidate_config.green.custom_hue == 'pea' ? 'NO! NOT PEA!' : nil
    }
    mod.define_group_validation_callback callback_class: Green, callback_method: :good_green
    mod.define_group_test_callback       callback_class: Green, callback_method: :try_green
  
  end
  
  def setup_configured_class_with_configured_modules
    simple_class = setup_simple_configured_class
    green_module = setup_simple_configured_module
    
    passthru_mod = new_configurable_module 'Passthru'
    passthru_mod.include Green
    simple_class.include Passthru
  end
  
  def setup_configured_class_with_configured_modules_and_base_classes
    setup_configured_class_with_configured_modules
    child_class = new_configurable_class 'Child', Simple
  end
  
  def new_configurable_class( name, base_class = nil )
    base_class ?  Object.const_set( name, Class.new(base_class) ) : Object.const_set( name, Class.new )
    new_class = Object.const_get name
    new_class.include Configh::Configurable
    @defined_modules_and_classes << new_class
    new_class
  end
  
  def new_configurable_module( name )
    Object.const_set name, Module.new
    new_module = Object.const_get name
    new_module.include Configh::Configurable
    @defined_modules_and_classes << new_module
    new_module
  end
  
  def test_configuration_class
    assert_equal Configh::ArrayBasedConfiguration, Configh::ConfigStore.configuration_class([])
    assert_equal Configh::MongoBasedConfiguration, Configh::ConfigStore.configuration_class( @@collection )
  end

  def test_configuration_class_invalid
    e = assert_raises Configh::UnsupportedStoreError do
      Configh::ConfigStore.configuration_class( 'not_a_store')
    end
    assert_equal 'Configuration store must be one of Array, Mongo::Collection', e.message
  end

  def test_copy_contents_without_validation_array_to_mongo
    @from_store = []
    @to_store = @@collection

    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @from_store, 'config1',
                                   { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config2',
                                   { 'simple' => { 'p1' => 'hello2', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config3',
                                   { 'simple' => { 'p1' => 'hello3', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config4',
                                  { 'simple' => { 'p1' => 'hello4', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config5',
                                  { 'simple' => { 'p1' => 'hello5', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    
    Configh::ConfigStore.copy_contents_without_validation( @from_store, @to_store )
    config_types_and_names = [ [Simple,'config1'], [Simple,'config2'], [Simple,'config3'], [Child,'config4'], [Child,'config5']]
    config_types_and_names.each do |config_type,config_name|
      from_config = config_type.find_configuration( @from_store, config_name )
      to_config   = config_type.find_configuration( @to_store, config_name)
      assert_equal from_config.__values, to_config.__values
      assert_equal from_config.__timestamp, to_config.__timestamp
      assert_equal from_config.__maintain_history, to_config.__maintain_history
    end
  end

  def test_copy_contents_without_validation_array_to_mongo_only_names
    @from_store = []
    @to_store = @@collection

    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @from_store, 'config1',
                                   { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config2',
                                   { 'simple' => { 'p1' => 'hello2', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config3',
                                   { 'simple' => { 'p1' => 'hello3', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config4',
                                  { 'simple' => { 'p1' => 'hello4', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config5',
                                  { 'simple' => { 'p1' => 'hello5', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }

    select_types_and_names = [ [Simple,'config1'],[Simple,'config3'], [Child,'config5'] ]
    select_names = select_types_and_names.collect{ |_t,n| n }

    Configh::ConfigStore.copy_contents_without_validation( @from_store, @to_store, names: select_names )
    select_types_and_names.each do |config_type,config_name|
      from_config = config_type.find_configuration( @from_store, config_name )
      to_config   = config_type.find_configuration( @to_store, config_name)
      assert_equal from_config.__values, to_config.__values
      assert_equal from_config.__timestamp, to_config.__timestamp
      assert_equal from_config.__maintain_history, to_config.__maintain_history
    end
  end

  def test_copy_contents_without_validation_mongo_to_array
    @from_store = @@collection
    @to_store = []

    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @from_store, 'config1',
                                   { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config2',
                                   { 'simple' => { 'p1' => 'hello2', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config3',
                                   { 'simple' => { 'p1' => 'hello3', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config4',
                                  { 'simple' => { 'p1' => 'hello4', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config5',
                                  { 'simple' => { 'p1' => 'hello5', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }

    Configh::ConfigStore.copy_contents_without_validation( @from_store, @to_store )
    config_types_and_names = [ [Simple,'config1'], [Simple,'config2'], [Simple,'config3'], [Child,'config4'], [Child,'config5']]
    config_types_and_names.each do |config_type,config_name|
      from_config = config_type.find_configuration( @from_store, config_name )
      to_config   = config_type.find_configuration( @to_store, config_name)
      assert_equal from_config.__values, to_config.__values
      assert_equal from_config.__timestamp, to_config.__timestamp
      assert_equal from_config.__maintain_history, to_config.__maintain_history
    end
  end

  def test_copy_contents_without_validation_mongo_to_array_only_names
    @from_store = @@collection
    @to_store = []

    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @from_store, 'config1',
                                   { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config2',
                                   { 'simple' => { 'p1' => 'hello2', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @from_store, 'config3',
                                   { 'simple' => { 'p1' => 'hello3', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config4',
                                  { 'simple' => { 'p1' => 'hello4', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @from_store, 'config5',
                                  { 'simple' => { 'p1' => 'hello5', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }

    select_types_and_names = [ [Simple,'config1'],[Simple,'config3'], [Child,'config5'] ]
    select_names = select_types_and_names.collect{ |_t,n| n }

    Configh::ConfigStore.copy_contents_without_validation( @from_store, @to_store, names: select_names )
    select_types_and_names.each do |config_type,config_name|
      from_config = config_type.find_configuration( @from_store, config_name )
      to_config   = config_type.find_configuration( @to_store, config_name)
      assert_equal from_config.__values, to_config.__values
      assert_equal from_config.__timestamp, to_config.__timestamp
      assert_equal from_config.__maintain_history, to_config.__maintain_history
    end
  end
end
