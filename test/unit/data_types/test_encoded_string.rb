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
require_relative '../../../lib/configh/data_types/encoded_string'

class TestEncodedString < Test::Unit::TestCase
  include Configh::DataTypes
  
  def test_plain_text
    text = 'plain text'
    enc = EncodedString.from_plain_text text
    assert_equal(text, enc.plain_text)
    assert_not_equal(text, enc.to_s)
  end

  def test_encoded
    text = 'encoded'
    enc = EncodedString.from_encoded(text)
    assert_equal(text, enc.encoded)
    assert_not_equal(text, enc.plain_text)
  end

  def test_to_s
    text = 'plain text'
    enc = EncodedString.from_plain_text(text)
    assert_equal(enc.to_s, enc.encoded)
  end
end
