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
require 'test/unit'
require_relative '../../../lib/configh/data_types/boolean'

class TestBoolean < Test::Unit::TestCase
  include Configh::DataTypes
  
  def test_equals
    assert_true  Boolean.new(true) == true
    assert_true  Boolean.new(false) == false
    assert_false Boolean.new(true) == false
    assert_false Boolean.new(false) == true

    assert_true  true == Boolean.new(true)
    assert_true  false == Boolean.new(false)
    assert_false false == Boolean.new(true)
    assert_false true == Boolean.new(false)
  end

  def test_triple_equals
    assert_true Boolean.new(true) === true
    assert_true Boolean.new(false) === false
    assert_false Boolean.new(true) === false
    assert_false Boolean.new(false) === true

    assert_true  true === Boolean.new(true)
    assert_true  false === Boolean.new(false)
    assert_false false === Boolean.new(true)
    assert_false true === Boolean.new(false)
  end

  def test_value
    assert_true Boolean.new(true)
    assert_false Boolean.new(false)
  end

  def test_bad_type
    assert_raise(TypeError) {Boolean.new(123)}
  end

  def test_if
    entered_true = false
    entered_false = false

    if Boolean.new(true)
      entered_true = true
    end

    if Boolean.new(true)
      entered_false = true
    end

    assert_true entered_true
    assert_true entered_false
  end

  def test_bool?
    assert_true Boolean.bool?(true)
    assert_true Boolean.bool?(false)
    assert_false Boolean.bool?(123)
  end
end
