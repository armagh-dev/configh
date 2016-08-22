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
require_relative '../../lib/configh/parameter'

require 'test/unit'
require 'mocha/test_unit'

class TestParameter < Test::Unit::TestCase
  
  def setup
    @name        = 'name'
    @description = 'description'
    @type        = 'string'
    @required    = false
    @default     = nil
    @prompt      = 'Number name blah'
    @group       = "group"
  end    
    
  def define_from_ivars
    
    Configh::Parameter.new(name: @name,
                              description: @description,
                              type: @type,
                              required: @required,
                              default: @default,
                              prompt: @prompt,
                              group: @group )
  end
  
  def assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message
    e = assert_raises Configh::ParameterDefinitionError do
      define_from_ivars
    end
    assert_equal "default value is not of correct type", e.message
  end
  
  def test_define_parameters_new_good

    p = define_from_ivars

    assert_equal( @name, p.name )
    assert_equal( @description, p.description )
    assert_equal( @type, p.type )
    assert_equal( @required, p.required ) 
    assert_equal( @default, p.default )
    assert_equal( @prompt, p.prompt )
    assert_equal( @group, p.group )
    
  end
  
  def test_define_parmaeters_new_types
    
    @type = 'integer'
    @default = 9;     assert_nothing_raised{ define_from_ivars }
    @default = "9";   assert_nothing_raised{ define_from_ivars }
    @default = -42;   assert_nothing_raised{ define_from_ivars }
    @default = "x";   assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message 
    
    @type = 'non_negative_integer'
    @default = 9;     assert_nothing_raised{ define_from_ivars }
    @default = -7;     assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message 
    
    @type = 'positive_integer'
    @default = 9;    assert_nothing_raised{ define_from_ivars }
    @default = 0;    assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message 
    
    @type = 'string'
    @default = 'hi'; assert_nothing_raised{ define_from_ivars }
    
    @type = 'populated_string'
    @default = 'hi'; assert_nothing_raised{ define_from_ivars }
    @default = ' ';  assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message
    @default = nil;  assert_nothing_raised{ define_from_ivars }
    
    @type = 'timestamp'
    @default = Time.now; assert_nothing_raised{ define_from_ivars }
    @default = Date.today; assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message
    
    @type = 'date'
    @default = Date.today; assert_nothing_raised { define_from_ivars }
    @default = Time.now;   assert_nothing_raised { define_from_ivars } 
     
    @type = 'boolean'
    @default = true; assert_nothing_raised { define_from_ivars }
    @default = false; assert_nothing_raised { define_from_ivars }
    @default = "you"; assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message
    
    @type = 'encoded_string'
    @default = Configh::DataTypes::EncodedString.from_plain_text( 'hi' ); assert_nothing_raised { define_from_ivars }
    @default = 'hi'; assert_parameter_definition_raises_parameter_definition_error_with_bad_default_message 
  end
  
  def assert_successful_validation( type, default, required, value, expected_value )
    @type = type
    @default = default
    @required = required
    p = define_from_ivars.validate( value )
    assert_equal expected_value, p.value
    assert_nil p.error
    assert_nil p.warning
  end
  
  def assert_fails_validation( type, default, required, value, expected_error_message )
    @type = type
    @default = default
    @required = required
    p = define_from_ivars.validate( value )
    assert_equal nil, p.value
    assert_equal expected_error_message, p.error
  end
  
  def test_validate
    
    d = Date.today
    t = Time.now.round
    es = Configh::DataTypes::EncodedString.from_plain_text( "i'm a secret" )
    
    assert_successful_validation( 'integer', nil, false, 4, 4 )
    assert_successful_validation( 'integer', 4, false, nil, 4 )
    assert_successful_validation( 'integer', 4, false, '4', 4 )
    assert_successful_validation( 'integer', 4, true, nil, 4 )
    assert_successful_validation( 'integer', nil, true, 4, 4 )
    assert_successful_validation( 'integer', nil, true, t, t.to_i)
    assert_fails_validation( 'integer', nil, true, nil, "type validation failed: value cannot be nil")
    assert_fails_validation( 'integer', nil, false, 'X', "type validation failed: value X cannot be cast as an integer")
 
    assert_successful_validation( 'non_negative_integer', nil, false, 0, 0 )
    assert_successful_validation( 'non_negative_integer', '0', false, nil, 0 )
    assert_successful_validation( 'non_negative_integer', nil, true, '0', 0 )
    assert_fails_validation( 'non_negative_integer', '0', true, 'x', 'type validation failed: value x cannot be cast as an integer')
    assert_fails_validation( 'non_negative_integer', nil, true, -134, 'type validation failed: value -134 is negative')

    assert_successful_validation( 'positive_integer', nil, true, 42, 42 )
    assert_successful_validation( 'positive_integer', nil, true, '42', 42 )
    assert_fails_validation( 'positive_integer', nil, true, 'x', 'type validation failed: value x cannot be cast as an integer' )
    assert_fails_validation( 'positive_integer', nil, false, 0, 'type validation failed: value 0 is non-positive')
    
    assert_successful_validation( 'populated_string', nil, true, 'hi', 'hi' )
    assert_fails_validation( 'populated_string', nil, true, '', 'type validation failed: string is empty or nil')
    
    assert_successful_validation( 'date', nil, true, d.strftime( "%Y-%m-%d"), d )
    assert_successful_validation( 'date', nil, false, nil, nil )
    assert_successful_validation( 'date', nil, true, d, d )
    assert_successful_validation( 'date', nil, true, t, d )
    assert_fails_validation( 'date', nil, true, '2016-10-40', 'type validation failed: value 2016-10-40 cannot be cast as a date')
        
    assert_successful_validation( 'timestamp', nil, true, t.strftime( "%Y-%m-%d %H:%M:%S %z" ), t)
    assert_successful_validation( 'timestamp', nil, true, t.strftime( "%a, %d %b %Y %H:%M:%S %z"), t )
    assert_fails_validation( 'timestamp', nil, true, d, "type validation failed: value #{ d.strftime( "%Y-%m-%d" )} cannot be cast as a timestamp")
    assert_fails_validation( 'timestamp', nil, true, "2016-10-05 25:60:00 GMT", "type validation failed: value 2016-10-05 25:60:00 GMT cannot be cast as a timestamp")
    
    assert_successful_validation( 'boolean', true, true, nil, true )
    assert_successful_validation( 'boolean', false, true, nil, false )
    assert_successful_validation( 'boolean', nil, true, false, false)
    assert_successful_validation( 'boolean', nil, false, nil, nil )
    assert_fails_validation( 'boolean', nil, false, 'x', 'type validation failed: value x is not boolean')
    
    assert_successful_validation( 'encoded_string', nil, true, es, es )
    assert_fails_validation( 'encoded_string', nil, true, 'yo', 'type validation failed: value yo is not an encoded string')
    
  end
  
  def test_all_errors
    
    p1 = Configh::Parameter.new( name: 'p1', description: 'p1', required: true, type: 'populated_string' )
    p1v = p1.validate( '' )
    p2 = Configh::Parameter.new( name: 'p2', description: 'p2', required: true, type: 'integer', group: 'subset')
    p2v = p2.validate( 'x' )
    p3 = Configh::Parameter.new( name: 'p3', description: 'p3', required: true, type: 'date' )
    p3v = p3.validate( Date.today )
    assert_equal [ "p1: type validation failed: string is empty or nil",
                   "subset p2: type validation failed: value x cannot be cast as an integer" 
                  ], Configh::Parameter.all_errors( [ p1v, p2v, p3v ])
  end

end
