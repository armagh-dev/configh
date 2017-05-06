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
  
  def test_create_for_simple_class_good
    setup_simple_configured_class
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'simple_inst',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'}})
    }
    assert_equal 'hello', config.simple.p1
    assert_equal 42, config.simple.p2
    assert_equal Date.today, config.simple.p3

    assert_raise{config.simple.p2 = '0'}
    assert_raise{config.simple.p1.gsub!('ello', 'owdy')}
  end
  
  def test_create_for_simple_class_bad_param
    setup_simple_configured_class
    config = nil
    e = assert_raises( Configh::ConfigInitError ) {
      config = Simple.create_configuration( @config_store, 'simple_bad', { 'simple' => { 'p1' => 'hello', 'p2' => 'x'}})
    }
    assert_equal 'Unable to create configuration Simple simple_bad: simple p2: type validation failed: value x cannot be cast as an integer', e.message
    assert_nil config
  end

  def test_create_for_simple_class_missing_param
    setup_simple_configured_class
    config = nil
    e = assert_raises( Configh::ConfigInitError ) {
      config = Simple.create_configuration( @config_store, 'simple_missing', { 'simple' => { 'p2' => 41 }})
    }
    assert_equal 'Unable to create configuration Simple simple_missing: simple p1: type validation failed: value cannot be nil', e.message
    assert_nil config
  end

  def test_create_for_simple_class_nonexistent_param
    setup_simple_configured_class
    config = nil
    e = assert_raises( Configh::ConfigInitError.new('Unable to create configuration Simple simple_nonex: simple nuhuh: Configuration provided for parameter that does not exist') ) {
      config = Simple.create_configuration( @config_store, 'simple_nonex', { 'simple' => { 'p1' => 'hello', 'p2' => 41, 'nuhuh' => false }})
    }

    e = assert_raises( Configh::ConfigInitError.new('Unable to create configuration Simple simple_nonex: nope nuhuh: Configuration provided for parameter that does not exist') ) {
      config = Simple.create_configuration( @config_store, 'simple_nonex', { 'simple' => { 'p1' => 'hello', 'p2' => 41 }, 'nope' => { 'nuhuh' => false }
      })
    }

  end

  def test_create_bad_store_class
    setup_configured_class_with_configured_modules_and_base_classes
    e =assert_raises( Configh::UnsupportedStoreError ) {
      Simple.create_configuration( Date.today, 'badstore', {} )
    }
    assert_equal 'Configuration store must be one of Array, Mongo::Collection', e.message
  end

  def test_create_dup_name
    setup_simple_configured_class
    assert_nothing_raised {
      Simple.create_configuration(@config_store, 'simple_inst', {'simple' => {'p1' => 'hello', 'p2' => '42'}})
    }
    e =assert_raises( Configh::ConfigInitError ) {
      Simple.create_configuration(@config_store, 'simple_inst', {} )
    }
    assert_equal 'Name already in use', e.message
  end

  def test_create_dup_name_casey
    setup_simple_configured_class
    assert_nothing_raised {
      Simple.create_configuration(@config_store, 'simple_inst', {'simple' => {'p1' => 'hello', 'p2' => '42'}})
    }
    e =assert_raises( Configh::ConfigInitError ) {
      Simple.create_configuration(@config_store, 'Simple_Inst', {} )
    }
    assert_equal 'Name already in use', e.message
  end


  def test_create_dup_name_maintain_history
    setup_simple_configured_class
    assert_nothing_raised {
      Simple.create_configuration(@config_store, 'simple_inst', {'simple' => {'p1' => 'hello', 'p2' => '42'}}, maintain_history: true)
    }
    e =assert_raises( Configh::ConfigInitError ) {
      Simple.create_configuration(@config_store, 'simple_inst', {} )
    }
    assert_equal 'Name already in use', e.message

  end
   
  def test_create_for_simple_module_good
    setup_simple_configured_module
    config = nil
    assert_nothing_raised do
      config = Green.create_configuration( @config_store, 'simple_mod_good',
                                           { 'green' => { 'custom_hue' => 'neon', 'web' => false }})
    end
    assert_equal 'neon', config.green.custom_hue
    assert_equal nil, config.green.rgb

    assert_raise{config.green.custom_hue.web = true}
    assert_raise{config.green.custom_hue.gsub!('eon', 'eat')}
  end
  
  def test_create_for_classes_and_modules_good
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised do
      config = Simple.create_configuration( @config_store, 'not_so_simple',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'neon', 'web' => false }})
    end
    assert_equal 'hello', config.simple.p1
    assert_equal 42, config.simple.p2
    assert_equal Date.today, config.simple.p3
    assert_equal 'neon', config.green.custom_hue
    assert_equal nil, config.green.rgb

    assert_raise{config.simple.p2 = '0'}
    assert_raise{config.simple.p1.gsub!('ello', 'owdy')}
    assert_raise{config.green.custom_hue.web = true}
    assert_raise{config.green.custom_hue.gsub!('eon', 'eat')}
  end

  def test_update_merge_no_history
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised do
      config = Simple.create_configuration( @config_store, 'not_so_simple_u1',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'neon', 'web' => false }})
    end
 #   sleep 1

    config.update_merge( { 'simple' => { 'p1' => 'hello again'}})
    assert_equal 'hello again', config.simple.p1
    assert_equal 42, config.simple.p2

    stored_config = Simple.find_configuration( @config_store, 'not_so_simple_u1')
    assert_equal 'hello again', stored_config.simple.p1

    assert_equal 1, stored_config.history.length
  end

  def test_update_merge_history
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'not_so_simple_u1',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'neon', 'web' => false }},
                                            :maintain_history => true)
    }

#    sleep 1
    config.update_merge( { 'simple' => { 'p1' => 'hello again'}})
    assert_equal 'hello again', config.simple.p1

    stored_config = Simple.find_configuration( @config_store, 'not_so_simple_u1')
    assert_equal 'hello again', stored_config.simple.p1

    assert_equal 2, stored_config.history.length

  end

  def test_update_merge_fail

    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised do
      config = Simple.create_configuration( @config_store, 'not_so_simple_u1',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'neon', 'web' => false }})
    end
#    sleep 1

    e = assert_raises( Configh::ConfigValidationError ) do
      config.update_merge( { 'simple' => { 'p2' => 'oops' }})
    end
    assert_equal 'simple p2: type validation failed: value oops cannot be cast as an integer', e.message

    assert_equal 'hello', config.simple.p1

    stored_config = Simple.find_configuration( @config_store, 'not_so_simple_u1' )
    assert_equal 'hello', stored_config.simple.p1
    assert_equal 1, stored_config.history.length
  end

  def test_update_replace_no_history
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    config_values = { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    assert_nothing_raised do
      config = Simple.create_configuration( @config_store, 'not_so_simple_u1', config_values )
    end
#    sleep 1

    config_values[ 'simple' ][ 'p1' ] = 'hello again'
    config.update_replace( config_values )
    assert_equal 'hello again', config.simple.p1

    stored_config = Simple.find_configuration( @config_store, 'not_so_simple_u1')
    assert_equal 'hello again', stored_config.simple.p1

    assert_equal 1, stored_config.history.length
  end

  def test_update_replace_history
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    config_values = { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    assert_nothing_raised do
      config = Simple.create_configuration( @config_store, 'not_so_simple_u1', config_values, maintain_history: true )
    end
 #   sleep 1

    config_values[ 'simple' ][ 'p1' ] = 'hello again'
    config.update_replace( config_values )
    assert_equal 'hello again', config.simple.p1

    stored_config = Simple.find_configuration( @config_store, 'not_so_simple_u1')
    assert_equal 'hello again', stored_config.simple.p1

    assert_equal 2, stored_config.history.length
  end

  def test_update_replace_fail
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    config_values = { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    assert_nothing_raised do
      config = Simple.create_configuration( @config_store, 'not_so_simple_u1', config_values )
    end
#    sleep 1

    config_values[ 'simple' ][ 'p2' ] = 'oops'
    e = assert_raises( Configh::ConfigValidationError ) do
      config.update_replace( config_values )
    end
    assert_equal 'hello', config.simple.p1

    stored_config = Simple.find_configuration( @config_store, 'not_so_simple_u1')
    assert_equal 'hello', stored_config.simple.p1

    assert_equal 1, stored_config.history.length
  end

  def test_refresh
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'refreshing',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_false config.refresh
  end
  
  def test_serialize
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'refreshing',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
  end
  
  def test_unserialize
    setup_configured_class_with_configured_modules_and_base_classes
    serialized_config = {'type'=>'Simple', 'name'=>'refreshing', 'timestamp'=>'2017-02-17 21:20:19 UTC',
                         'maintain_history'=>'false', 'values'=>{'green'=>{'custom_hue'=>'neon'},
                         'simple'=>{'p1'=>'hello', 'p2'=>'42', 'p3'=>'2017-02-17'}}}
    assert_nothing_raised {
      Configh::Configuration.unserialize(serialized_config)
    }
  end

  def test_unserialize_with_invalid_configuration
    setup_configured_class_with_configured_modules_and_base_classes
    serialized_config = {'type'=>'Simple', 'name'=>'refreshing', 'timestamp'=>'2017-02-17 21:20:19 UTC',
                         'maintain_history'=>'false',
                         'values'=>{'green'=>{'custom_hue'=>'neon'},
                                    'simple'=>{'p1'=>'hello', 'p2'=>'42', 'p3'=>'2017-02-17'}}}
    Configh::Configuration.stubs(:get_target_datatype).returns(false)
    e = assert_raises( Configh::ConfigInitError ) {
      Configh::Configuration.unserialize(serialized_config)
    }
    assert_equal 'Invalid and/or Unsupported Configuration for Group: "green" Parameters: {"custom_hue"=>"neon"} Key: "custom_hue" Value: "neon"', e.message
  end

  def test_find
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'finder',
                                   { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      config = Simple.find_configuration( @config_store, 'finder' )
    }
    found_params = config.find_all_parameters{ |p| p.group == 'simple' }
    assert_equal [ 'hello', 42, Date.today ], found_params.collect{ |p| p.value }
  end 

  def test_find_not_found
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'finder',
                                   { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
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
    assert_equal 'Configuration store must be one of Array, Mongo::Collection', e.message
  end 

  def test_find_or_create_found
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'finder',
                                   { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      config = Simple.find_or_create_configuration( @config_store, 'finder' )
    }
    found_params = config.find_all_parameters{ |p| p.group == 'simple' }
    assert_equal [ 'hello', 42, Date.today ], found_params.collect{ |p| p.value }
  end 

  def test_find_or_create_not_found
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.find_or_create_configuration( @config_store, 'finder',
                                                    values_for_create: { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                                                                         'green' => { 'custom_hue' => 'neon',
                                                                                      'web' => false }})
    }
    found_params = config.find_all_parameters{ |p| p.group == 'simple' }
    assert_equal [ 'hello', 42, Date.today ], found_params.collect{ |p| p.value }
  end 
  
  def test_find_all
    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'config1',
                                   { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config2',
                                   { 'simple' => { 'p1' => 'hello2', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config3',
                                   { 'simple' => { 'p1' => 'hello3', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config4',
                                  { 'simple' => { 'p1' => 'hello4', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config5',
                                  { 'simple' => { 'p1' => 'hello5', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal %w{ config1 config2 config3 },
                 Simple.find_all_configurations( @config_store ).collect{ |klass, config| config.__name }.sort
    assert_equal %w{ config4 config5 },
                 Child.find_all_configurations( @config_store ).collect{ |klass, config| config.__name }.sort
    assert_equal %w{ config1 config2 config3 config4 config5 },
                 Simple.find_all_configurations( @config_store, include_descendants: true )
                     .collect{ |klass, config| config.__name }.sort
  end

  def test_find_all_raw
    setup_configured_class_with_configured_modules_and_base_classes
    assert_nothing_raised {
      Simple.create_configuration( @config_store, 'config1',
                                   { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config2',
                                   { 'simple' => { 'p1' => 'hello2', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Simple.create_configuration( @config_store, 'config3',
                                   { 'simple' => { 'p1' => 'hello3', 'p2' => '42'},
                                     'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config4',
                                  { 'simple' => { 'p1' => 'hello4', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
      Child.create_configuration( @config_store, 'config5',
                                  { 'simple' => { 'p1' => 'hello5', 'p2' => '42'},
                                    'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal %w{config1 config2 config3},
                 Simple.find_all_configurations( @config_store, raw: true ).collect{ |_k,h| h['name'] }.sort
    assert_equal %w{config4 config5},
                 Child.find_all_configurations( @config_store, raw: true ).collect{ |_k,h| h['name'] }.sort
    assert_equal %w{config1 config2 config3 config4 config5},
                 Simple.find_all_configurations( @config_store, raw: true, include_descendants: true )
                     .collect{ |_k, h| h['name'] }.sort
  end
  
  def test_tests_ok
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'config1',
                                            { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'neon', 'web' => false }})
    }
    assert_equal( {}, config.test_and_return_errors )
  end    

  def test_tests_bad
    setup_configured_class_with_configured_modules_and_base_classes
    config = nil
    assert_nothing_raised {
      config = Simple.create_configuration( @config_store, 'config1',
                                            { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                                              'green' => { 'custom_hue' => 'pea', 'web' => false }})
    }
    assert_equal( {'try_green'=>'NO! NOT PEA!'}, config.test_and_return_errors )
  end    

  def test_get_target_datatype
    setup_configured_class_with_configured_modules_and_base_classes
    serialized_config = {'type'=>'Simple', 'name'=>'refreshing', 'timestamp'=>'2017-02-17 21:20:19 UTC',
                         'maintain_history'=>'false',
                         'values'=>{'green'=>{'custom_hue'=>'neon'},
                                    'simple'=>{'p1'=>'hello', 'p2'=>'42', 'p3'=>'2017-02-17'}}}
    type = eval(serialized_config['type'])
    params = type.defined_parameters
    assert_equal 'string', Configh::Configuration.get_target_datatype(params, 'green', 'custom_hue')
  end

  def test_get_target_datatype_with_invalid_configuration
    setup_configured_class_with_configured_modules_and_base_classes
    serialized_config = {'type'=>'Simple', 'name'=>'refreshing', 'timestamp'=>'2017-02-17 21:20:19 UTC',
                         'maintain_history'=>'false',
                         'values'=>{'green'=>{'custom_hue'=>'neon'},
                                    'simple'=>{'p1'=>'hello', 'p2'=>'42', 'p3'=>'2017-02-17'}}}
    type = eval(serialized_config['type'])
    params = type.defined_parameters
    assert_nil Configh::Configuration.get_target_datatype(params, 'red', 'crimson')
  end

  def test_get_readers
    setup_simple_configured_class

    config = nil
    assert_nothing_raised do
      config = Simple.create_configuration( @config_store, 'simple_inst2',
                                            { 'simple' => { 'p1' => 'hello', 'p2' => '42'}}, maintain_history: true)
    end
    assert_equal 'simple_inst2', config.__name
    assert_true  config.__maintain_history
    assert_equal Time, config.__timestamp.class
    assert_equal Simple, config.__type
  end

  def test_dup_values
    setup_configured_class_with_configured_modules_and_base_classes
    config_values = { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    config = Simple.create_configuration( @config_store, 'config1', config_values )
    assert_equal 'hello1', config.simple.p1
    assert_equal 42, config.simple.p2
    assert_equal 'neon', config.green.custom_hue
    assert_equal false, config.green.web

    dupped_values = config.duplicate_values
    assert_equal 'hello1', dupped_values[ 'simple' ][ 'p1' ]
    assert_equal 42, dupped_values[ 'simple' ][ 'p2' ]
    assert_equal 'neon', dupped_values[ 'green' ][ 'custom_hue' ]
    assert_equal false, dupped_values[ 'green' ][ 'web' ]

    assert_not_same config_values[ 'simple' ][ 'p1' ], dupped_values[ 'simple' ][ 'p1']
    assert_not_same config_values[ 'simple' ][ 'p2' ], dupped_values[ 'simple' ][ 'p2']
    assert_not_same config_values[ 'green' ][ 'custom_hue' ], dupped_values[ 'simple' ][ 'custom_hue']
    assert_not_same config_values[ 'green' ][ 'web' ], dupped_values[ 'simple' ][ 'web']
  end

  def test_change_history
    setup_configured_class_with_configured_modules_and_base_classes
    config_values = { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    config = Simple.create_configuration( @config_store, 'config1', config_values, maintain_history: true )

#    sleep 1
    config_values['simple'].delete 'p2'
    config_values[ 'simple'][ 'p1' ] = 'goodbye'
    config.update_replace config_values

    change_history = []
    assert_nothing_raised do
      change_history = config.change_history
    end
    assert_equal 2, change_history.length
    assert_nothing_raised{ Time.parse( change_history.first[ 'at' ] )}
    assert_equal 'simple parameter p1', change_history.first[ 'param' ]
    assert_equal 'hello1', change_history.first[ 'was' ]
    assert_equal 'goodbye', change_history.first[ 'became' ]
    assert_nothing_raised{ Time.parse( change_history.last[ 'at' ] )}
    assert_equal 'simple parameter p2', change_history.last[ 'param' ]
    assert_equal '42', change_history.last[ 'was' ]
    assert_equal '4', change_history.last[ 'became' ]

  end

  def test_config_values_valid?
    setup_configured_class_with_configured_modules_and_base_classes
    config_values = { 'simple' => { 'p1' => 'hello', 'p2' => '42'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    assert_true Simple.configuration_values_valid?( config_values )
  end

  def test_config_values_valid_not
    setup_configured_class_with_configured_modules_and_base_classes
    config_values = { 'simple' => { 'p1' => 'hello', 'p2' => 'oops'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    assert_false Simple.configuration_values_valid?( config_values )
  end

  def test_edit_configuration
    setup_configured_class_with_configured_modules_and_base_classes
    config_values = { 'simple' => { 'p1' => 'hello', 'p2' => 'oops'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    edit_info = Simple.edit_configuration( config_values )
    assert_equal 6, edit_info['parameters'].length
    assert_equal Simple, edit_info['type']
    assert_equal 'type validation failed: value oops cannot be cast as an integer',
                 edit_info['parameters'].find{ |p| p['error']}['error']
  end

  def test_max_timestamp
    setup_configured_class_with_configured_modules_and_base_classes
    config_values = { 'simple' => { 'p1' => 'hello1', 'p2' => '42'},
                      'green' => { 'custom_hue' => 'neon', 'web' => false }}
    simple_config = nil
    child_config = nil
    assert_nothing_raised {
      simple_config = Simple.create_configuration( @config_store, 'config1', config_values, maintain_history: true )
      Simple.create_configuration( @config_store, 'config2', config_values, maintain_history: true )
      Simple.create_configuration( @config_store, 'config3', config_values, maintain_history: true )
      child_config = Child.create_configuration( @config_store, 'config4', config_values, maintain_history: true )
      Child.create_configuration( @config_store, 'config5', config_values, maintain_history: true )
    }
    ts1 = Simple.max_timestamp( @config_store )

    config_values['simple'].delete 'p2'
    config_values[ 'simple'][ 'p1' ] = 'goodbye'
    simple_config.update_replace config_values
    ts2 = Simple.max_timestamp( @config_store )

    Child.create_configuration( @config_store, 'config6', config_values, maintain_history: true )
    ts3 = Simple.max_timestamp( @config_store )

    config_values[ 'simple' ][ 'p1' ] = 'byebye'
    child_config.update_replace config_values
    ts4 = Simple.max_timestamp( @config_store )

    assert_true [ ts1, ts2, ts3, ts4 ] == [ ts1, ts2, ts3, ts4 ].sort
  end


end
