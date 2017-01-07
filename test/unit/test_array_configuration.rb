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

#require_relative '../../helpers/coverage_helper'
require_relative '../../lib/configh/configuration'
require_relative '../../lib/configh/configurable'

require 'test/unit'
require 'mocha/test_unit'

class TestArrayConfiguration < Test::Unit::TestCase
  
  def setup
    
    @config_store = []
    @defined_modules_and_classes = []
    
  end
  
  def teardown
    Object.module_eval "
      %w{ #{@defined_modules_and_classes.join(" ")} }.each do |c|
        remove_const c if const_defined? c
      end"
  end
  
  def setup_simple_configured_class
    
    klass = nil   
    d = Date.today
    bogus_class = new_configurable_class 'Bogus'
    bogus_class.define_singleton_method( 'bogus_validate' ){ |config| }
    bogus_class.define_singleton_method( 'bogus_test' ){ |config| }
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
    mod.define_singleton_method( 'good_green' ) { |candidate_config|
      
      error = nil
      if candidate_config.green.web
        error = "must provide an RGB value for web colors" if candidate_config.green.rgb.nil?
      else
        allowed_custom_hues = %w{ lime pea neon olive }
        h = candidate_config.green.custom_hue
        error = "hue #{h} not one of allowed values: #{ allowed_hues.join(", ")}" unless allowed_custom_hues.include?( h )
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
  
  def test_create_for_simple_class_good
    setup_simple_configured_class
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'simple_inst', { 'simple' => { 'p1' => 'hello', 'p2' => '42'}})
    }
    assert_equal 'hello', config.simple.p1
    assert_equal 42, config.simple.p2
    assert_equal Date.today, config.simple.p3
  end
  
  def test_create_for_simple_class_bad_param
    setup_simple_configured_class
    config = nil
    e = assert_raises( Configh::ConfigInitError ) {
      config = Simple.create_configuration( @config_store, 'simple_bad', { 'simple' => { 'p1' => 'hello', 'p2' => 'x'}})
    }
    assert_equal "Unable to create configuration Simple simple_bad: simple p2: type validation failed: value x cannot be cast as an integer", e.message
    assert_nil config
  end

  def test_create_for_simple_class_missing_param
    setup_simple_configured_class
    config = nil
    e = assert_raises( Configh::ConfigInitError ) {
      config = Simple.create_configuration( @config_store, 'simple_missing', { 'simple' => { 'p2' => 41 }})
    }
    assert_equal "Unable to create configuration Simple simple_missing: simple p1: type validation failed: value cannot be nil", e.message
    assert_nil config
  end

  def test_create_bad_store_class
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    e =assert_raises( Configh::UnsupportedStoreError ) {
      Simple.create_configuration( Date.today, 'badstore', {} )
    }
    assert_equal "Configuration store must be one of Array, Mongo::Collection", e.message
  end 
   
  def test_create_for_simple_module_good
    setup_simple_configured_module
    config = nil
    assert_nothing_raised {
      config = Green.create_configuration( @config_store, 'simple_mod_good', { 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal 'neon', config.green.custom_hue
    assert_equal nil, config.green.rgb
  end
  
  def test_create_for_classes_and_modules_good
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'not_so_simple', { 'simple' => { 'p1' => 'hello', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal 'hello', config.simple.p1
    assert_equal 42, config.simple.p2
    assert_equal Date.today, config.simple.p3
    assert_equal 'neon', config.green.custom_hue
    assert_equal nil, config.green.rgb
  end
   
  def test_refresh
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'refreshing', { 'simple' => { 'p1' => 'hello', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_false config.refresh
  end
  
  def test_serialize
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'refreshing', { 'simple' => { 'p1' => 'hello', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
  end
  
  def
     
  def test_find
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'finder', { 'simple' => { 'p1' => 'hello', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      config = Simple.find_configuration( @config_store, 'finder' )
    }
    found_params = config.find_all_parameters{ |p| p.group == 'simple' }
    assert_equal [ 'hello', 42, Date.today ], found_params.collect{ |p| p.value }
  end 

  def test_find_not_found
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'finder', { 'simple' => { 'p1' => 'hello', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      config = Simple.find_configuration( @config_store, 'oops' )
    }
    assert_nil config
  end 

  def test_find_bad_store_class
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    e =assert_raises( Configh::UnsupportedStoreError ) {
      Simple.find_configuration( Date.today, 'badstore' )
    }
    assert_equal "Configuration store must be one of Array, Mongo::Collection", e.message
  end 

  def test_find_or_create_found
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'finder', { 'simple' => { 'p1' => 'hello', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      config = Simple.find_or_create_configuration( @config_store, 'finder' )
    }
    found_params = config.find_all_parameters{ |p| p.group == 'simple' }
    assert_equal [ 'hello', 42, Date.today ], found_params.collect{ |p| p.value }
  end 

  def test_find_or_create_not_found
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.find_or_create_configuration( @config_store, 'finder', values_for_create: { 'simple' => { 'p1' => 'hello', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    found_params = config.find_all_parameters{ |p| p.group == 'simple' }
    assert_equal [ 'hello', 42, Date.today ], found_params.collect{ |p| p.value }
  end 
  
  def test_find_all
    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'config1', { 'simple' => { 'p1' => 'hello1', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config2', { 'simple' => { 'p1' => 'hello2', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config3', { 'simple' => { 'p1' => 'hello3', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config4', { 'simple' => { 'p1' => 'hello4', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config5', { 'simple' => { 'p1' => 'hello5', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal [ 'config1', 'config2', 'config3' ], Simple.find_all_configurations( @config_store ).collect{ |klass, config| config.__name }.sort
    assert_equal [ 'config4', 'config5' ], Child.find_all_configurations( @config_store ).collect{ |klass, config| config.__name }.sort
    assert_equal [ 'config1', 'config2', 'config3', 'config4', 'config5' ], Simple.find_all_configurations( @config_store, include_descendants: true ).collect{ |klass, config| config.__name }.sort
  end

  def test_find_all_raw
    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'config1', { 'simple' => { 'p1' => 'hello1', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config2', { 'simple' => { 'p1' => 'hello2', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config3', { 'simple' => { 'p1' => 'hello3', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config4', { 'simple' => { 'p1' => 'hello4', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config5', { 'simple' => { 'p1' => 'hello5', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal [ 'config1', 'config2', 'config3' ], Simple.find_all_configurations( @config_store, raw: true ).collect{ |_k,h| h['name'] }.sort
    assert_equal [ 'config4', 'config5' ], Child.find_all_configurations( @config_store, raw: true ).collect{ |_k,h| h['name'] }.sort
    assert_equal [ 'config1', 'config2', 'config3', 'config4', 'config5' ], Simple.find_all_configurations( @config_store, raw: true, include_descendants: true ).collect{ |_k, h| h['name'] }.sort
  end
  
  def test_tests_ok
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'config1', { 'simple' => { 'p1' => 'hello1', 'p2' => '42'}, 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal( {}, config.test_and_return_errors )
  end    

  def test_tests_bad
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'config1', { 'simple' => { 'p1' => 'hello1', 'p2' => '42'}, 'green' => { 'custom_hue' => 'pea', 'web' => false }})
    }
    assert_equal( {"try_green"=>"NO! NOT PEA!"}, config.test_and_return_errors )
  end    

end

  
  
 