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
require 'test/unit'
require_relative '../../lib/configh/data_types'

class TestDataTypes < Test::Unit::TestCase
  
  def test_ensure_is_integer
    t = Time.now
    assert_equal 42, Configh::DataTypes.ensure_is_integer(42)
    assert_equal 42, Configh::DataTypes.ensure_is_integer('42')
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_integer( '42 is the answer' )
    end
    assert_equal "value 42 is the answer cannot be cast as an integer", e.message
    assert_equal t.to_i, Configh::DataTypes.ensure_is_integer( Time.now )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_integer( nil )
    end
    assert_equal "value  cannot be cast as an integer", e.message
  end
    
  def test_ensure_is_non_negative_integer
    t = Time.now
    assert_equal 42, Configh::DataTypes.ensure_is_non_negative_integer(42)
    assert_equal 42, Configh::DataTypes.ensure_is_non_negative_integer('42')
    assert_equal t.to_i, Configh::DataTypes.ensure_is_non_negative_integer( t )
    assert_equal 0, Configh::DataTypes.ensure_is_non_negative_integer( 0 )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer('-42')
    end
    assert_equal "value -42 is negative", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer( '42 is the answer')
    end
    assert_equal "value 42 is the answer cannot be cast as an integer", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer( -20 )
    end
    assert_equal "value -20 is negative", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer( nil )
    end
    assert_equal "value  cannot be cast as an integer", e.message
  end
  
  def test_ensure_is_positive_integer
    t = Time.now
    assert_equal 42, Configh::DataTypes.ensure_is_positive_integer(42)
    assert_equal 42, Configh::DataTypes.ensure_is_positive_integer('42')
    assert_equal t.to_i, Configh::DataTypes.ensure_is_positive_integer( t )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( 0 )
    end
    assert_equal "value 0 is non-positive", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer('-42')
    end
    assert_equal "value -42 is non-positive", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( '42 is the answer')
    end
    assert_equal "value 42 is the answer cannot be cast as an integer", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( -20 )
    end
    assert_equal "value -20 is non-positive", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( nil )
    end
    assert_equal "value  cannot be cast as an integer", e.message
  end
 
  def test_ensure_is_string
    d = Date.civil 1964, 7, 30
    t = Time.new 2016, 8, 7, 15, 56, 00
    assert_equal "Now is the time.", Configh::DataTypes.ensure_is_string( 'Now is the time.')
    assert_equal "42", Configh::DataTypes.ensure_is_string( 42 ) 
    assert_equal "-20", Configh::DataTypes.ensure_is_string( -20 )
    assert_equal d.strftime("%Y-%m-%d"), Configh::DataTypes.ensure_is_string( d )
    assert_equal t.strftime("%Y-%m-%d %H:%M:%S %z"), Configh::DataTypes.ensure_is_string( t )
    assert_equal 'true', Configh::DataTypes.ensure_is_string( true )
    assert_equal "", Configh::DataTypes.ensure_is_string( nil )
    assert_equal "", Configh::DataTypes.ensure_is_string( "" )
    assert_equal " ", Configh::DataTypes.ensure_is_string( " " )
  end
  
  def test_ensure_is_populated_string
    d = Date.civil 1964, 7, 30
    t = Time.new 2016, 8, 7, 15, 56, 00
    assert_equal "Now is the time.", Configh::DataTypes.ensure_is_populated_string( 'Now is the time.')
    assert_equal "42", Configh::DataTypes.ensure_is_populated_string( 42 ) 
    assert_equal "-20", Configh::DataTypes.ensure_is_populated_string( -20 )
    assert_equal d.strftime("%Y-%m-%d"), Configh::DataTypes.ensure_is_populated_string( d )
    assert_equal t.strftime("%Y-%m-%d %H:%M:%S %z"), Configh::DataTypes.ensure_is_populated_string( t )
    assert_equal 'true', Configh::DataTypes.ensure_is_populated_string( true )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_populated_string( nil )
    end
    assert_equal "string is empty or nil", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_populated_string( "" )
    end
    assert_equal "string is empty or nil", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_populated_string( " " )
    end
    assert_equal "string is empty or nil", e.message
  end

  def test_ensure_is_date
    d = Date.civil 1964, 7, 30
    assert_equal d, Configh::DataTypes.ensure_is_date( d )
    assert_equal d, Configh::DataTypes.ensure_is_date( '19640730' )
    assert_equal d, Configh::DataTypes.ensure_is_date( '1964-07-30' )
    assert_equal d, Configh::DataTypes.ensure_is_date( '30 Jul 1964' )
    assert_equal d, Configh::DataTypes.ensure_is_date( 'Thu, 30 Jul 1964 00:00:00 GMT' )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_date( "I'm not a date" )
    end
    assert_equal "value I'm not a date cannot be cast as a date", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_date( 4 )
    end
    assert_equal "value 4 cannot be cast as a date", e.message
  end

  def test_ensure_is_timestamp
    t = Time.utc 1964, 07, 30, 15, 56, 00
    assert_equal t, Configh::DataTypes.ensure_is_timestamp( t )
    assert_equal t, Configh::DataTypes.ensure_is_timestamp( t.strftime( "%Y-%m-%d %H:%M:%S %z"))
    assert_equal t, Configh::DataTypes.ensure_is_timestamp( t.strftime( "%a, %d %b %Y %H:%M:%S GMT") )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_timestamp( "I'm not a timestamp" )
    end
    assert_equal "value I'm not a timestamp cannot be cast as a timestamp", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_date( 4 )
    end
    assert_equal "value 4 cannot be cast as a date", e.message
  end

  def test_ensure_is_boolean
    assert_equal true, Configh::DataTypes.ensure_is_boolean( true )
    assert_equal false, Configh::DataTypes.ensure_is_boolean( false )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_boolean( nil )
    end
    assert_equal "value  is not boolean", e.message
  end
  
  def test_ensure_is_encoded_string
    es = Configh::DataTypes::EncodedString.from_plain_text( "Hi there" )
    assert_equal es, Configh::DataTypes.ensure_is_encoded_string( es )   
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_encoded_string( "Hi I'm a string." )
    end
    assert_equal "value Hi I'm a string. is not an encoded string", e.message
  end
  
  def test_ensure_is_symbol
    assert_equal :fred, Configh::DataTypes.ensure_is_symbol( :fred )
    assert_equal :fred, Configh::DataTypes.ensure_is_symbol( 'fred' )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_symbol 4
    end
    assert_equal "value 4 cannot be cast as a symbol", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_symbol nil
    end
    assert_equal "value  cannot be cast as a symbol", e.message
  end
  
  def test_ensure_value_is_datatype
    t = Time.now
    d = Date.today
    es = Configh::DataTypes::EncodedString.from_plain_text( "Killer bunny")
    assert_equal 42, Configh::DataTypes.ensure_value_is_datatype( 42, 'integer' )
    assert_equal 0, Configh::DataTypes.ensure_value_is_datatype( 0, 'non_negative_integer' )
    assert_equal 20, Configh::DataTypes.ensure_value_is_datatype( "20", 'positive_integer' )
    assert_equal "s", Configh::DataTypes.ensure_value_is_datatype( "s", 'string' )
    assert_equal "", Configh::DataTypes.ensure_value_is_datatype( "", 'string' )
    assert_equal "s", Configh::DataTypes.ensure_value_is_datatype( "s", 'populated_string')
    assert_equal true, Configh::DataTypes.ensure_value_is_datatype( true, 'boolean' )
    assert_equal Date.today, Configh::DataTypes.ensure_value_is_datatype( Date.today.strftime( "%Y-%m-%d"), 'date')
    assert_equal es, Configh::DataTypes.ensure_value_is_datatype( es, 'encoded_string')
    assert_equal nil, Configh::DataTypes.ensure_value_is_datatype( nil, 'integer', true )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_value_is_datatype( nil, 'integer' )
    end
    assert_equal "value cannot be nil", e.message
  end
  
  def test_not_supported
    assert_false Configh::DataTypes.supported?( 'im_not_a_type' )
    Configh::DataTypes.define_singleton_method( :ensure_is_fred ){ |x| }
    assert_true Configh::DataTypes.supported?( 'fred' )
  end
end