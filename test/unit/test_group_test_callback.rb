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

require_relative '../helpers/coverage_helper'

require_relative '../../lib/configh/group_validation_callback'

require 'test/unit'
require 'mocha/test_unit'

class CalledBackTestClass
  
  def self.called_back_method( candidate_config )
    
    error = nil
    error = "boom" if candidate_config&.dig( 'group1', 'imagoboom') 
    error 
  end 
  
  def self.called_back_method_invalid( candidate_config )
    return 4
  end
  
end

class TestGroupTestCallback < Test::Unit::TestCase
  
  def setup
    @candidate_config = { 'group1' => { 'imagoboom' => false }}
    @bad_config = { 'group1' => { 'imagoboom' => true }}
  end

  def test_group_set
    cb = Configh::GroupTestCallback.new( callback_class: CalledBackTestClass, callback_method: :called_back_method, group: 'fred' )
    assert_equal 'fred', cb.group
  end
  def test_success
    cb = Configh::GroupTestCallback.new( callback_class: CalledBackTestClass, callback_method: :called_back_method )
    assert_nil cb.test_and_return_error_string( @candidate_config )
  end
  
  def test_fail
    cb =   Configh::GroupTestCallback.new( callback_class: CalledBackTestClass, callback_method: :called_back_method )
    assert_equal(  'boom', cb.test_and_return_error_string( @bad_config ) )
  end
  
  def test_flawed_callback
    cb = Configh::GroupTestCallback.new( callback_class: CalledBackTestClass, callback_method: :called_back_method_invalid )
    e = assert_raises( Configh::GroupTestCallbackLogicError ){ cb.test_and_return_error_string( @candidate_config )}
    assert_equal "callback method CalledBackTestClass.called_back_method_invalid returned 4 instead of a string or nil", e.message
  end
  
  def test_nonexistent_callback
    cb = Configh::GroupTestCallback.new( callback_class: CalledBackTestClass, callback_method: :i_dont_exist )
    e = assert_raises( Configh::GroupTestCallbackLogicError) { cb.test_and_return_error_string( @candidate_config )}
    assert_equal "callback method CalledBackTestClass.i_dont_exist not defined", e.message
  end
    

end