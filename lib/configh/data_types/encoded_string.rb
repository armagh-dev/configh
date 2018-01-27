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

require 'base64'

module Configh
  module DataTypes
    class EncodedString
  
      def self.from_plain_text( plain_text )
        new( Base64.encode64( plain_text ))
      end
  
      def self.from_encoded( encoded )
        new( encoded )
      end
    
      def initialize( encoded )
        @encoded_string = encoded
      end
  
      def to_s
        @encoded_string
      end
  
      def plain_text
        Base64.decode64( @encoded_string )
      end

      def encoded
        to_s
      end
      
      def ==(other)
        @encoded_string == other.to_s
      end
      
    end
  end
end