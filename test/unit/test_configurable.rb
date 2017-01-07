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
require_relative '../../lib/configh/configurable'
require_relative '../../lib/configh/mongo_based_configuration'

require 'test/unit'
require 'mocha/test_unit'


class TestConfigurable < Test::Unit::TestCase
  
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
      Bogus.define_singleton_method( 'bogus_validate') {|values| }
      Bogus.define_singleton_method( 'bogus_test'){ |values| }
      klass = new_configurable_class 'Simple'
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus_validate
      klass.define_group_test_callback       callback_class: Bogus, callback_method: :bogus_test
    }
    
    assert_equal [ 'p1', 'p2', 'p3' ], klass.defined_parameters.collect{ |p| p.name }
    assert_equal [ 'p1', 'p3' ], klass.required_parameters.collect{ |p,i| p.name }
    assert_equal [ 'p2', 'p3' ], klass.parameters_with_defaults.collect{ |p,i| p.name }
    
    assert_equal Bogus, klass.defined_group_validation_callbacks.first.callback_class
    assert_equal Bogus, klass.defined_group_test_callbacks.first.callback_class
    
    config = klass.create_configuration( @config_store, 'simple1', { 'simple' => { 'p1' => 'hello!', 'p2' => '5' }})
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
      mod.define_singleton_method( 'try_green' ) { |candidate_config| nil }
      mod.define_group_validation_callback callback_class: Green, callback_method: :good_green
      mod.define_group_test_callback callback_class: Green, callback_method: :try_green
      
      
      mod_config = mod.create_configuration( @config_store, 'modules1', { 'green' => { 'hue' => 'neon', 'rgb' => '140.140.140' }})
      
      mod = new_configurable_module 'Passthrough'
      mod.include Green
      
      klass = new_configurable_class 'Bogus'
      Bogus.define_singleton_method('bogus_validate') {|values| }
      Bogus.define_singleton_method('bogus_test') {|values| }
      klass = new_configurable_class 'Simple'
      klass.include Passthrough
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus_validate
      klass.define_group_test_callback       callback_class: Bogus, callback_method: :bogus_test
      
      config = klass.create_configuration( @config_store, 'complex', { 'simple' => { 'p1' => 'hello!', 'p2' => '5' }, 'green' => { 'hue' => 'olive'}})
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
      Bogus.define_singleton_method( 'bogus_test') {|values| }
      Bogus.define_singleton_method( 'bogus_validate' ) { |values| }
      klass = new_configurable_class 'Simple'
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d, group: 'special'
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus_validate
      klass.define_group_test_callback       callback_class: Bogus, callback_method: :bogus_test
     
      child_klass = new_configurable_class 'Child', Simple
      child_klass.define_parameter name: 'px', description: 'this is px', type: 'integer', required: false, default: 1
      
      config = child_klass.create_configuration( @config_store, 'inherit1', { 'simple' => { 'p1' => 'hello!', 'p2' => '5' } })
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
      Bogus.define_singleton_method( 'bogus_test') {|values| }
      Bogus.define_singleton_method( 'bogus_validate' ){ |values| }
      klass = new_configurable_class 'Simple'
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d, group: 'special'
      klass.define_group_validation_callback callback_class: Bogus, callback_method: :bogus_validate
      klass.define_group_test_callback       callback_class: Bogus, callback_method: :bogus_test
   
      child_klass = new_configurable_class 'Child', Simple
      child_klass.define_parameter name: 'px', description: 'this is px', type: 'integer', required: false, default: 1
    
      config = child_klass.create_configuration( @config_store, 'inherit2', { 'simple' => { 'p1' => 'hello!', 'p2' => '5' } })
      assert_equal 'hello!', config.simple.p1
      assert_equal 5, config.simple.p2
      assert_equal d, config.special.p3
      assert_equal 1, config.child.px   
    }
  end
  
  def test_redef_params_within_class
    
    klass = nil
    
    d = Date.today
    assert_nothing_raised {
      klass = new_configurable_class 'Bogus'
      Bogus.define_singleton_method( 'bogus_validate') {|values| }
      Bogus.define_singleton_method( 'bogus_test' ){ |values| }
      klass = new_configurable_class 'Simple'
      klass.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true, default: 'hi'
      klass.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
      klass.define_parameter name: 'p2', description: 'this is the real p2', type: 'string', required: true, default: 'yay'
      klass.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d, group: 'explicit'
      klass.define_parameter name: 'p3', description: 'this is another p3', type: 'integer', required: true, default: 7
      klass.define_parameter name: 'p4', description: 'poof', type: 'integer', required: true, default: 10, group: 'other'
      klass.define_parameter name: 'p4', description: 'here', type: 'string', required: true, default: 'yo', group: 'other'
   
      assert_equal 5, klass.defined_parameters.length
      
      config = klass.create_configuration( @config_store, 'class1', {} )
      assert_equal 'hi', config.simple.p1
      assert_equal 'yay', config.simple.p2
      assert_equal d, config.explicit.p3
      assert_equal 7, config.simple.p3
      assert_equal 'yo', config.other.p4
    }
  end
  
  def test_redef_params_across_classes
    
      klass = nil
    
      d = Date.today
      assert_nothing_raised {
        klass = new_configurable_class 'Bogus'
        Bogus.define_singleton_method( 'bogus') {|values| }
        simple_class = new_configurable_class 'Simple'
        other_class = new_configurable_class 'Other', Simple
        
        simple_class.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true, default: 'hi'
        simple_class.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4, group: 'dim'
        other_class.define_parameter name: 'p2', description: 'this is the real p2', type: 'string', required: true, default: 'yay', group: 'dim'
        simple_class.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d, group: 'explicit'
        simple_class.define_parameter name: 'p3', description: 'this is another p3', type: 'integer', required: true, default: 7
        simple_class.define_parameter name: 'p4', description: 'poof', type: 'integer', required: true, default: 10, group: 'bling'
        other_class.define_parameter name: 'p4', description: 'here', type: 'string', required: true, default: 'yo', group: 'bling'
   
        assert_equal 5, other_class.defined_parameters.length
      
        config = other_class.create_configuration( @config_store, 'class2', {} )
        assert_equal 'hi', config.simple.p1
        assert_equal 'yay', config.dim.p2
        assert_equal d, config.explicit.p3
        assert_equal 7, config.simple.p3
        assert_equal 'yo', config.bling.p4
      }
    end
  
end