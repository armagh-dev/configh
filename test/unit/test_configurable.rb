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

#require_relative '../../helpers/coverage_helper'
require_relative '../../lib/configh/configurable'
require_relative '../../lib/configh/mongo_based_configuration'

require 'test/unit'
require 'mocha/test_unit'


class TestConfigurable < Test::Unit::TestCase
  
  def setup
    
    @defined_modules_and_classes = []
  end
  
  def teardown
    Object.module_eval "
      %w{ #{@defined_modules_and_classes.join(" ")} }.each do |c|
        remove_const c if const_defined? c
      end"
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
  
  
  def test_includable
    assert_nothing_raised { new_configurable_class 'Simple' }
    assert_nothing_raised { new_configurable_module 'Green' }
  end
  
  def test_simple_class
    
    klass = nil
    
    d = Date.today
    assert_nothing_raised {
      klass = new_configurable_class 'Bogus'
      Bogus.define_singleton_method( 'bogus') {|values| }
      klass = new_configurable_class 'Simple'
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus
    }
    
    assert_equal [ 'p1', 'p2', 'p3' ], klass.defined_parameters.collect{ |p| p.name }
    assert_equal [ 'p1', 'p3' ], klass.required_parameters.collect{ |p,i| p.name }
    assert_equal [ 'p2', 'p3' ], klass.parameters_with_defaults.collect{ |p,i| p.name }
    
    assert_equal Bogus, klass.defined_group_validation_callbacks.first.callback_class
    
    config = klass.use_static_config_values( { 'simple' => { 'p1' => 'hello!', 'p2' => '5' }})
    assert_equal 'hello!', config.simple.p1
    assert_equal 5, config.simple.p2
    assert_equal d, config.simple.p3
    
  end
  
  def test_class_with_modules
    
    d = Date.today
    assert_nothing_raised {
      
      mod = new_configurable_module 'Green'
      mod.define_parameter name: 'hue', description: 'shade of green', type: 'string', required: true, default: 'lime'
      mod.define_parameter name: 'rgb', description: 'rgb value', type: 'string', required: false
      mod.define_singleton_method( 'good_green' ) { |candidate_config|
        
        allowed_hues = %w{ lime pea neon olive }
        h = candidate_config.green.hue
        "hue #{h} not one of allowed values: #{ allowed_hues.join(", ")}" unless allowed_hues.include?( h )
      
      }
      mod.define_group_validation_callback callback_class: Green, callback_method: :good_green
      mod_config = mod.use_static_config_values( { 'green' => { 'hue' => 'neon', 'rgb' => '140.140.140' }})
      
      mod = new_configurable_module 'Passthrough'
      mod.include Green
      
      klass = new_configurable_class 'Bogus'
      Bogus.define_singleton_method('bogus') {|values| }
      klass = new_configurable_class 'Simple'
      klass.include Passthrough
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus
      
      config = klass.use_static_config_values( { 'simple' => { 'p1' => 'hello!', 'p2' => '5' }, 'green' => { 'hue' => 'olive'}})
      assert_equal 'hello!', config.simple.p1
      assert_equal 5, config.simple.p2
      assert_equal d, config.simple.p3
      assert_equal 'olive', config.green.hue     
    }
  end
  
  def test_class_with_inheritance
    
    d = Date.today
    assert_nothing_raised {
      
      klass = new_configurable_class 'Bogus'
      Bogus.define_singleton_method( 'bogus') {|values| }
      klass = new_configurable_class 'Simple'
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d, group: 'special'
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus
     
      child_klass = new_configurable_class 'Child', Simple
      child_klass.define_parameter name: 'px', description: 'this is px', type: 'integer', required: false, default: 1
      
      config = child_klass.use_static_config_values( { 'simple' => { 'p1' => 'hello!', 'p2' => '5' } })
      assert_equal 'hello!', config.simple.p1
      assert_equal 5, config.simple.p2
      assert_equal d, config.special.p3
      assert_equal 1, config.child.px   
    }
  end
    
  def test_class_with_inheritance_parent_has_configured_by
  
    d = Date.today
    assert_nothing_raised {
    
      klass = new_configurable_class 'Bogus'
      Bogus.define_singleton_method( 'bogus') {|values| }
      klass = new_configurable_class 'Simple'
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d, group: 'special'
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus
      klass.configured_by Configh::MongoBasedConfiguration
   
      child_klass = new_configurable_class 'Child', Simple
      child_klass.define_parameter name: 'px', description: 'this is px', type: 'integer', required: false, default: 1
    
      assert child_klass.const_get('ConfigurationFactory') < Configh::MongoBasedConfiguration
      config = child_klass.use_static_config_values( { 'simple' => { 'p1' => 'hello!', 'p2' => '5' } })
      assert_equal 'hello!', config.simple.p1
      assert_equal 5, config.simple.p2
      assert_equal d, config.special.p3
      assert_equal 1, config.child.px   
    }
  end
end