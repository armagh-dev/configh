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
require_relative '../../lib/configh/mongo_based_configuration'
require_relative '../../lib/configh/configurable'

require 'mongo'

require 'test/unit'
require 'mocha/test_unit'

class TestIntegMongoBasedConfiguration < Test::Unit::TestCase
    
  class << self
    
    def startup
      begin
        try_start_mongo
        try_connect
        @@collection = @@connection[ 'config' ]
        @@collection.drop
      rescue
        puts "unable to start mongo"
        exit
      end
    end
    
    def try_start_mongo
      @@pid = nil
      psline = `ps -ef | grep mongod | grep -v grep`
      if psline.empty?
        puts "trying to start mongod..."
        @@pid = spawn 'mongod 1>/dev/null 2>&1'
        sleep 5
      else 
        puts "mongod was running at entry.  will be left running"
        return      
      end
      Process.detach @@pid
      raise if `ps -ef | grep mongod | grep -v grep`.empty?
      puts "mongod successfully started."
      
    end
  
    def try_connect
      Mongo::Logger.logger.level = ::Logger::FATAL
      @@connection = Mongo::Client.new( 
        [ '127.0.0.1:27017' ], 
        :database=>'test_integ_mongo_based_config', 
        :server_selection_timeout => 5,
        :connect_timeout => 5
      )
      @@connection.collections
    end
    
    def shutdown
      if @@pid
        puts "\nshutting down mongod"
        `kill \`pgrep mongod\``
      end
    end
  end
  
  def setup
    @klass = nil   
    @defined_modules_and_classes = []
    
    d = Date.today
    @simple_class = new_configurable_class 'Simple'
    @simple_class.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true
    @simple_class.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4
    @simple_class.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d
    @simple_class.configured_by Configh::MongoBasedConfiguration

    @complete_class = new_configurable_class 'Complete'
    @complete_class.define_parameter name: 'p1', description: 'this is p1', type: 'string', required: true, default: 'def string'
    @complete_class.define_parameter name: 'p2', description: 'this is p2', type: 'integer', required: false, default: 4, writable:true 
    @complete_class.define_parameter name: 'p3', description: 'this is p3', type: 'date', required: true, default: d
    @complete_class.configured_by Configh::MongoBasedConfiguration
    
    @@collection.drop
  end
  
  def teardown
    Object.module_eval "
      %w{ #{@defined_modules_and_classes.join(" ")} }.each do |c|
        remove_const c if const_defined? c
      end"  
  end
  
  def new_configurable_class( name, base_class = nil )
    base_class ?  Object.const_set( name, Class.new(base_class) ) : Object.const_set( name, Class.new )
    new_class = Object.const_get name
    new_class.include Configh::Configurable
    @defined_modules_and_classes << new_class
    new_class
  end
  
  def test_get_good
  
    t = Time.now
       
    config = nil
    assert_nothing_raised { config = @complete_class.use_named_config( @@collection, 'fred' )  }
    assert_equal 'def string', config.complete.p1
    assert_equal 4, config.complete.p2
    assert_equal Date.today, config.complete.p3
    
  end
  
  def test_get_nothing_found_cant_build
    t = Time.now
       
    config = nil
    e = assert_raises Configh::ConfigInitError do
      @simple_class.use_named_config( @@collection, 'fred' )
    end
    assert_equal "No Simple configuration found named fred and unable to create from defaults: simple p1: type validation failed: value cannot be nil", e.message
  end

  def test_get_nothing_found_can_build
    t = Time.now
    
    new_config = { 
      'type' => 'Complete',
      'name' => 'alice',
      'values' => { 'complete' => { 'p1' => 'def string', 'p2' => 4, 'p3' => Date.today }}
    }
    
    config = nil  
    assert_nothing_raised { config = @complete_class.use_named_config( @@collection, 'alice' ) }
    assert_equal 4, config.complete.p2
  end
  
  def test_use_static_values
    
    config = @complete_class.use_static_config_values( {'complete' => { 'p1' => 'hi' }})
    assert_equal 'hi', config.complete.p1
  end
  
  def test_writable
    
    config1 = nil
    assert_nothing_raised { config1 = @complete_class.use_named_config( @@collection, 'alice' )}
    assert_nothing_raised { config1.complete.p2 = 7 }
    assert_equal 7, config1.complete.p2
    
    config2 = nil
    assert_nothing_raised { config2 = @complete_class.use_named_config( @@collection, 'alice' )}
    assert_not_same config1, config2
    assert_equal 7, config2.complete.p2
    
  end
  
  def test_history
    
    config_history = nil
    assert_nothing_raised { 
      config = @complete_class.use_named_config( @@collection, 'alice', true )
      3.times do |i|
        sleep 2
        config.complete.p2 = i
      end
      config_history = config.history
    }
    history_of_p2 = config_history.collect{ |ts,v| v[ 'complete'][ 'p2' ]}
    history_of_ts = config_history.collect{ |ts,_v| ts }
    assert_equal [ 4,0,1,2 ], history_of_p2
    assert_equal history_of_ts.sort, history_of_ts
    
  end
end
  
  