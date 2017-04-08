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

require_relative 'data_types.rb'

module Configh
  
  class GroupValidationCallbackLogicError < StandardError; end
  
  class GroupValidationCallback
    attr_accessor :callback_class, :callback_method, :group, :error
    
    def initialize( callback_class:, callback_method:, group: nil )
      @callback_class = callback_class
      @callback_method = callback_method.to_sym
      @group = group
      @error = nil
    end 
    
    def validate( candidate_config )
      
      flagged_vc = self.dup
      unless @callback_class&.respond_to? @callback_method
        raise GroupValidationCallbackLogicError, "callback method #{ @callback_class }.#{ @callback_method } not defined"
      end
      returned_error = @callback_class.send( @callback_method, candidate_config )
      unless returned_error.nil? or returned_error.is_a? String
        raise GroupValidationCallbackLogicError, "callback method #{ @callback_class }.#{ @callback_method } returned #{returned_error} instead of a string or nil"
      end
      flagged_vc.error = returned_error
      flagged_vc
    end

    def to_hash
      Hash[[ 'group', 'error'].collect{ |pname| [ pname, send( pname.to_sym ) ]}]
    end
      
  end    
end