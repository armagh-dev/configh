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

class TestConfigStore < Test::Unit::TestCase
  
  def setup
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
    coll = mock('coll')
    coll.stubs(:class).returns( Mongo::Collection)
    assert_equal Configh::ArrayBasedConfiguration, Configh::ConfigStore.configuration_class([])
    assert_equal Configh::MongoBasedConfiguration, Configh::ConfigStore.configuration_class( coll)
  end

  def test_configuration_class_invalid
    e = assert_raises Configh::UnsupportedStoreError do
      Configh::ConfigStore.configuration_class( 'not_a_store')
    end
    assert_equal 'Configuration store must be one of Array, Mongo::Collection', e.message
  end

  def test_copy_contents_without_validation
    @from_store = []
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
    assert_equal @from_store, @to_store
    assert_not_same @from_store, @to_store

  end

  def test_copy_contents_without_validation_only_names
    @from_store = []
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

    select_names = %w( config1 config3 )

    Configh::ConfigStore.copy_contents_without_validation( @from_store, @to_store, names: select_names )
    expected_to_store = @from_store.select{ |c| select_names.include? c['name']}
    assert_equal expected_to_store, @to_store

  end

end
