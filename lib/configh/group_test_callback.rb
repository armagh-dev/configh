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

module Configh
  
  class GroupTestCallbackLogicError < StandardError; end
  
  class GroupTestCallback
    attr_accessor :callback_class, :callback_method, :group, :name, :error
    
    def initialize( callback_class:, callback_method:, group: nil, name: nil )
      @callback_class = callback_class
      @callback_method = callback_method.to_sym
      @group = group
      @name  = name
      @error = nil
    end 
    
    def test_and_return_error_string( candidate_config )
      
      returned_error = nil
      unless @callback_class&.respond_to? @callback_method
        raise GroupTestCallbackLogicError, "callback method #{ @callback_class }.#{ @callback_method } not defined"
      end
      returned_error = @callback_class.send( @callback_method, candidate_config )
      unless returned_error.nil? or returned_error.is_a? String
        raise GroupTestCallbackLogicError, "callback method #{ @callback_class }.#{ @callback_method } returned #{returned_error} instead of a string or nil"
      end
      returned_error
    end
      
  end    
end
