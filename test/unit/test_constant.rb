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

require_relative '../../lib/configh/constant'

require 'test/unit'
require 'mocha/test_unit'

class TestConstant < Test::Unit::TestCase

  def setup
    @name        = 'name'
    @value       = 'value'
    @group       = 'group'
  end

  def test_initialize
    c = Configh::Constant.new(name: @name, value: @value, group: @group)
    assert_equal @name, c.name
    assert_equal @value, c.value
    assert_equal @group, c.group
  end

  def test_initialize_no_group
    c = Configh::Constant.new(name: @name, value: @value)
    assert_equal @name, c.name
    assert_equal @value, c.value
    assert_nil c.group
  end

  def test_initialize_bad_name
    assert_raise(Configh::ConstantDefinitionError){Configh::Constant.new(name: '____', value: @value, group: @group)}
  end
 end
