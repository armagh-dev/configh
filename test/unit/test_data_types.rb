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

require 'test/unit'
require_relative '../../lib/configh/data_types'
require 'mocha/test_unit'

class WeirdType
  undef :to_s
end

class VulnerabilityTestObject
  def bad
  end
end

class TestDataTypes < Test::Unit::TestCase

  def setup
    VulnerabilityTestObject.expects(:bad).never
  end
  
  def test_ensure_is_integer
    t = Time.now
    assert_equal 42, Configh::DataTypes.ensure_is_integer(42)
    assert_equal 42, Configh::DataTypes.ensure_is_integer('42')
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_integer( '42 is the answer', nullable: false )
    end
    assert_equal "value '42 is the answer' cannot be cast as an integer", e.message
    assert_equal t.to_i, Configh::DataTypes.ensure_is_integer( Time.now, nullable: false )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_integer( nil, nullable: false )
    end
    assert_equal "value '' cannot be cast as an integer", e.message
  end
    
  def test_ensure_is_non_negative_integer
    t = Time.now
    assert_equal 42, Configh::DataTypes.ensure_is_non_negative_integer(42, nullable: false)
    assert_equal 42, Configh::DataTypes.ensure_is_non_negative_integer('42', nullable: false)
    assert_equal t.to_i, Configh::DataTypes.ensure_is_non_negative_integer( t, nullable: false )
    assert_equal 0, Configh::DataTypes.ensure_is_non_negative_integer( 0, nullable: false )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer('-42', nullable: false)
    end
    assert_equal "value '-42' is negative", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer( '42 is the answer', nullable: false)
    end
    assert_equal "value '42 is the answer' cannot be cast as an integer", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer( -20, nullable: false )
    end
    assert_equal "value '-20' is negative", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_non_negative_integer( nil, nullable: false )
    end
    assert_equal "value '' cannot be cast as an integer", e.message
  end
  
  def test_ensure_is_positive_integer
    t = Time.now
    assert_equal 42, Configh::DataTypes.ensure_is_positive_integer(42, nullable: false)
    assert_equal 42, Configh::DataTypes.ensure_is_positive_integer('42', nullable: false)
    assert_equal t.to_i, Configh::DataTypes.ensure_is_positive_integer( t, nullable: false )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( 0, nullable: false )
    end
    assert_equal "value '0' is non-positive", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer('-42', nullable: false)
    end
    assert_equal "value '-42' is non-positive", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( '42 is the answer', nullable: false)
    end
    assert_equal "value '42 is the answer' cannot be cast as an integer", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( -20, nullable: false )
    end
    assert_equal "value '-20' is non-positive", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_positive_integer( nil, nullable: false )
    end
    assert_equal "value '' cannot be cast as an integer", e.message
  end
 
  def test_ensure_is_string
    d = Date.civil 1964, 7, 30
    t = Time.new 2016, 8, 7, 15, 56, 00
    assert_equal "Now is the time.", Configh::DataTypes.ensure_is_string( 'Now is the time.', nullable: false)
    assert_equal "42", Configh::DataTypes.ensure_is_string( 42, nullable: false )
    assert_equal "-20", Configh::DataTypes.ensure_is_string( -20, nullable: false )
    assert_equal d.strftime("%Y-%m-%d"), Configh::DataTypes.ensure_is_string( d, nullable: false )
    assert_equal t.strftime("%Y-%m-%d %H:%M:%S %z"), Configh::DataTypes.ensure_is_string( t, nullable: false )
    assert_equal 'true', Configh::DataTypes.ensure_is_string( true, nullable: false )
    assert_equal "", Configh::DataTypes.ensure_is_string( nil, nullable: true )
    assert_equal "", Configh::DataTypes.ensure_is_string( "", nullable: true )
    assert_equal " ", Configh::DataTypes.ensure_is_string( " ", nullable: true )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_string( nil, nullable: false )
    end
    assert_equal "string is empty or nil", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_string( "", nullable: false )
    end
    assert_equal "string is empty or nil", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_string( " ", nullable: false )
    end
    assert_equal "string is empty or nil", e.message
  end

  def test_ensure_is_date
    d = Date.civil 1964, 7, 30
    assert_equal d, Configh::DataTypes.ensure_is_date( d, nullable: false)
    assert_equal d, Configh::DataTypes.ensure_is_date( '19640730', nullable: false )
    assert_equal d, Configh::DataTypes.ensure_is_date( '1964-07-30', nullable: false )
    assert_equal d, Configh::DataTypes.ensure_is_date( '30 Jul 1964', nullable: false )
    assert_equal d, Configh::DataTypes.ensure_is_date( 'Thu, 30 Jul 1964 00:00:00 GMT', nullable: false )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_date( "I'm not a date", nullable: false )
    end
    assert_equal "value 'I'm not a date' cannot be cast as a date", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_date( 4, nullable: false )
    end
    assert_equal "value '4' cannot be cast as a date", e.message
  end

  def test_ensure_is_timestamp
    t = Time.utc 1964, 07, 30, 15, 56, 00
    assert_equal t, Configh::DataTypes.ensure_is_timestamp( t, nullable: false )
    assert_equal t, Configh::DataTypes.ensure_is_timestamp( t.strftime( "%Y-%m-%d %H:%M:%S %z"), nullable: false)
    assert_equal t, Configh::DataTypes.ensure_is_timestamp( t.strftime( "%a, %d %b %Y %H:%M:%S GMT"), nullable: false )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_timestamp( "I'm not a timestamp" , nullable: false)
    end
    assert_equal "value 'I'm not a timestamp' cannot be cast as a timestamp", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_date( 4, nullable: false )
    end
    assert_equal "value '4' cannot be cast as a date", e.message
  end

  def test_ensure_is_boolean
    assert_equal true, Configh::DataTypes.ensure_is_boolean( true, nullable: false )
    assert_equal false, Configh::DataTypes.ensure_is_boolean( false, nullable: false )

    assert_equal true, Configh::DataTypes.ensure_is_boolean( 'true', nullable: false )
    assert_equal false, Configh::DataTypes.ensure_is_boolean( 'false', nullable: false )


    assert_raise(Configh::DataTypes::TypeError.new("value '' is not boolean")) {Configh::DataTypes.ensure_is_boolean(nil, nullable: false)}
  end
  
  def test_ensure_is_encoded_string
    es = Configh::DataTypes::EncodedString.from_plain_text( "Hi there" )
    assert_equal es, Configh::DataTypes.ensure_is_encoded_string( es, nullable: false )
    
    uns = Configh::DataTypes.ensure_is_encoded_string( es.to_s, nullable: false )
    assert_equal 'Hi there', uns.plain_text
  end
  
  def test_ensure_is_symbol
    assert_equal :fred, Configh::DataTypes.ensure_is_symbol( :fred, nullable: false )
    assert_equal :fred, Configh::DataTypes.ensure_is_symbol( 'fred', nullable: false )
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_symbol 4, nullable: false
    end
    assert_equal "value '4' cannot be cast as a symbol", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_is_symbol nil, nullable: false
    end
    assert_equal "value '' cannot be cast as a symbol", e.message
  end

  def test_ensure_is_string_array
    assert_equal %w(a b c d e), Configh::DataTypes.ensure_is_string_array(%w(a b c d e), nullable: false)
    assert_equal %w(1 2 3), Configh::DataTypes.ensure_is_string_array([1,2,3], nullable: false)
    assert_equal %w(a b c d e), Configh::DataTypes.ensure_is_string_array( %w(a b c d e).inspect, nullable: false)


    assert_raise(Configh::DataTypes::TypeError.new("value '123' is not an array of strings")){
      Configh::DataTypes.ensure_is_string_array(123, nullable: false)
    }

    assert_raise(Configh::DataTypes::TypeError.new("value '\\3' is not an array of strings")){
      Configh::DataTypes.ensure_is_string_array('\3', nullable: false)
    }

    e = assert_raise(Configh::DataTypes::TypeError){
      Configh::DataTypes.ensure_is_string_array([WeirdType.new], nullable: false)
    }
    assert_include(e.message, 'is not an array of elements that could be converted to strings')

    assert_raise(Configh::DataTypes::TypeError.new("value 'VulnerabilityTestObject.bad' is not an array of strings")) {
      Configh::DataTypes.ensure_is_string_array('VulnerabilityTestObject.bad', nullable: false)
    }
  end

  def test_ensure_is_symbol_array
    assert_equal [:a, :b, :c, :d, :e], Configh::DataTypes.ensure_is_symbol_array(%w(a b c d e), nullable: false)
    assert_equal [:a, :b, :c, :d, :e], Configh::DataTypes.ensure_is_symbol_array([ :a, :b, :c, :d, :e ], nullable: false)
    assert_equal [:a, :b, :c, :d, :e], Configh::DataTypes.ensure_is_symbol_array([ :a, :b, :c, :d, :e ].to_json, nullable: false)

    assert_raise(Configh::DataTypes::TypeError.new("value '123' is not an array of symbols")){
      Configh::DataTypes.ensure_is_symbol_array(123, nullable: false)
    }

    assert_raise(Configh::DataTypes::TypeError.new("value '\\3' is not an array of symbols")){
      Configh::DataTypes.ensure_is_symbol_array('\3', nullable: false)
    }

    e = assert_raise(Configh::DataTypes::TypeError){
      Configh::DataTypes.ensure_is_symbol_array([WeirdType.new], nullable: false)
    }
    assert_include(e.message, 'is not an array of elements that could be converted to symbols')

    assert_raise(Configh::DataTypes::TypeError.new("value 'VulnerabilityTestObject.bad' is not an array of symbols")) {
      Configh::DataTypes.ensure_is_symbol_array('VulnerabilityTestObject.bad', nullable: false)
    }
  end
  
  def test_ensure_value_is_datatype
    t = Time.now
    d = Date.today
    es = Configh::DataTypes::EncodedString.from_plain_text( "Killer bunny")
    assert_equal 42, Configh::DataTypes.ensure_value_is_datatype( 42, 'integer' )
    assert_equal 0, Configh::DataTypes.ensure_value_is_datatype( 0, 'non_negative_integer' )
    assert_equal 20, Configh::DataTypes.ensure_value_is_datatype( "20", 'positive_integer' )
    assert_equal "s", Configh::DataTypes.ensure_value_is_datatype( "s", 'string' )
    assert_equal "", Configh::DataTypes.ensure_value_is_datatype( "", 'string', true )
     assert_equal true, Configh::DataTypes.ensure_value_is_datatype( true, 'boolean' )
    assert_equal Date.today, Configh::DataTypes.ensure_value_is_datatype( Date.today.strftime( "%Y-%m-%d"), 'date')
    assert_equal es, Configh::DataTypes.ensure_value_is_datatype( es, 'encoded_string')
    assert_equal nil, Configh::DataTypes.ensure_value_is_datatype( nil, 'integer', true )
    assert_equal ['one', 'two'], Configh::DataTypes.ensure_value_is_datatype(%w(one two), 'string_array' )
    assert_equal [:one, :two], Configh::DataTypes.ensure_value_is_datatype(%w(one two), 'symbol_array' )
    assert_equal({'one' => 'two'}, Configh::DataTypes.ensure_value_is_datatype('{"one": "two"}', 'hash'))
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_value_is_datatype( nil, 'integer' )
    end
    assert_equal "value cannot be nil", e.message
    e = assert_raise Configh::DataTypes::TypeError do
      Configh::DataTypes.ensure_value_is_datatype( '', 'string')
    end
    assert_equal "string is empty or nil", e.message
  end
  
  def test_ensure_is_hash
    assert_equal({}, Configh::DataTypes.ensure_is_hash({}, nullable: false))
    assert_equal({}, Configh::DataTypes.ensure_is_hash({}.to_json, nullable: false))
    assert_equal({'a' => '1', 'b' => '[1, 2, 3]'}, Configh::DataTypes.ensure_is_hash({'a' => 1, 'b' => [1, 2, 3]}, nullable: false))
    assert_equal({'a' => '1', 'b' => '[1, 2, 3]'}, Configh::DataTypes.ensure_is_hash({'a' => 1, 'b' => [1, 2, 3]}.to_json, nullable: false))

    assert_raise(Configh::DataTypes::TypeError.new("value 'VulnerabilityTestObject.bad' is not a hash of strings")) {
      Configh::DataTypes.ensure_is_hash('VulnerabilityTestObject.bad')
    }
  end
  
  def test_not_supported
    assert_false Configh::DataTypes.supported?( 'im_not_a_type' )
    Configh::DataTypes.define_singleton_method( :ensure_is_fred ){ |x| }
    assert_true Configh::DataTypes.supported?( 'fred' )
  end
  
  def test_encoded_string_equal
    e1 = Configh::DataTypes::EncodedString.from_plain_text 'same'
    e2 = Configh::DataTypes::EncodedString.from_plain_text 'same'
    e3 = Configh::DataTypes::EncodedString.from_plain_text 'different'
    assert_equal e1, e2
    assert_not_equal e1, e3
  end

  def test_ensure_is_object
    assert_equal({}, Configh::DataTypes.ensure_is_object({}, nullable: false))
    assert_equal(123, Configh::DataTypes.ensure_is_object(123, nullable: false))
  end
end
