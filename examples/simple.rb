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

require 'configh'

class Agent
  include Configh::Configurable
  
  attr_accessor :config
  
  define_parameter name: 'agent_name', description: 'name of this agent profile',         type: 'populated_string', required: true
  define_parameter name: 'threads',    description: 'maximum number of threads to spawn', type: 'positive_integer', required: true, default: 1
  define_parameter name: 'engine',     description: 'processing engine to default to',    type: 'string'
  
  define_group_validation_callback callback_class: Agent, callback_method: :validate_thread_limits
  
  configured_by Configh::MongoBasedConfiguration
  
  ENGINE_THREAD_LIMITS = { 'lion' => 6, 'tiger' => 20, 'bear' => 2 }
  
  def Agent.validate_thread_limits( candidate_config )
    
    error_string = nil
    
    thread_limit = ENGINE_THREAD_LIMITS[ candidate_config.agent.engine ]
    if thread_limit &. < candidate_config.agent.threads
      error_string = "Thread count #{ candidate_config.agent.threads } exceeds #{ candidate_config.agent.engine } limit of #{ thread_limit }."
    end
    
    error_string
    
  end
  
  def initialize( config )
    @config = config
  end
  
end

##
# Use Agent.use_static_config_values to set values during testing.  Values are filled in as needed with 
# defaults and validated before use.
#
config = Agent.use_static_config_values( {'agent' => { 'agent_name' => 'fred', 'threads' => 6, 'engine' => 'tiger'}})
puts config.agent.agent_name  #=> 'fred'
puts config.agent.threads #=> 6
puts config.agent.engine #=> tiger
puts "---"

config = Agent.use_static_config_values( {'agent' => { 'agent_name' => 'fred' }})
puts config.agent.agent_name  #=> 'fred'
puts config.agent.threads #=> 1 - default added
puts config.agent.engine #=> nil
puts "---"

config = Agent.use_static_config_values( {'agent' => { 'agent_name' => 'fred', 'threads' => '6' }})  # note 6 is a string now
puts config.agent.agent_name  #=> 'fred'
puts config.agent.threads #=> 6 
puts config.agent.threads.class #=> Fixnum
puts config.agent.engine #=> nil
puts "---"


begin
  config = Agent.use_static_config_values( {'agent' => { 'threads' => '6' }}) 
rescue Configh::ConfigValidationError => e
  puts e.inspect #=> notice
end

begin 
  config = Agent.use_static_config_values( { 'agent' => { 'agent_name' => 'bill', 'threads' => 100, 'engine' => 'bear' }})
rescue Configh::ConfigValidationError => e
  puts e.inspect
end

###
#
# use Agent.use_named_config( 'fred' ) 