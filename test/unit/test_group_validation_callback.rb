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
require_relative '../../lib/configh/group_validation_callback'

require 'test/unit'
require 'mocha/test_unit'

class CalledBackClass
  
  def self.called_back_method( candidate_config )
    
    error = nil
    error = "group1 sum isn't 3" unless candidate_config&.dig( 'group1', 'p1') + candidate_config&.dig( 'group1', 'p2') == 3
    error 
  end 
  
  def self.called_back_method_invalid( candidate_config )
    return 4
  end
  
end

class TestGroupValidationCallback < Test::Unit::TestCase
  
  def setup
    @candidate_config = { 'group1' => { 'p1' => 1, 'p2' => 2}, 'group2' => { 'px' => 'x'}}
  end
  
  def test_success
    gvc = Configh::GroupValidationCallback.new( callback_class: CalledBackClass, callback_method: :called_back_method )
    assert_nil gvc.validate( @candidate_config ).error
  end
  
  def test_fail
    @candidate_config[ 'group1' ][ 'p1' ] = 4
    gvc = Configh::GroupValidationCallback.new( callback_class: CalledBackClass, callback_method: :called_back_method )
    assert_equal "group1 sum isn't 3", gvc.validate( @candidate_config ).error
  end
  
  def test_flawed_callback
    gvc = Configh::GroupValidationCallback.new( callback_class: CalledBackClass, callback_method: :called_back_method_invalid )
    e = assert_raises( Configh::GroupValidationCallbackLogicError ){ gvc.validate( @candidate_config )}
    assert_equal "callback method CalledBackClass.called_back_method_invalid returned 4 instead of a string or nil", e.message
  end
  
  def test_nonexistent_callback
    gvc = Configh::GroupValidationCallback.new( callback_class: CalledBackClass, callback_method: :i_dont_exist )
    e = assert_raises( Configh::GroupValidationCallbackLogicError) { gvc.validate( @candidate_config )}
    assert_equal "callback method CalledBackClass.i_dont_exist not defined", e.message
  end
    

end