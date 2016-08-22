

require_relative './base_configuration'

module Configh
  
  class MongoBasedConfiguration < PersistedConfiguration
  
    def self.initialize_from_named_config( collection, name = 'default', maintain_history = false )
      mbc = new( collection, name, maintain_history )
      mbc.load_named_config
      mbc
    end
    
    def self.initialize_from_static_values( values_hash )
      mbc = new( nil, nil, false )
      mbc.reset_values_to( values_hash )
      mbc
    end
    
    def initialize( collection, name=nil, maintain_history=false )
      raise "Name must be specified if collection is given" if ( collection and not name )
      super( name )
      @__collection = collection
      @__maintain_history = maintain_history
    end
     
    def get
      begin
        config_in_db = @__collection.aggregate( [
           { '$match' => { 'type' => @__type, 'name' => @__config_name } },
           { '$sort'  => { 'timestamp' => -1 }},
           { '$limit' => 1 }
         ]).first
      rescue => e
        raise e.class, "Problem pulling #{ @__type } configuration '#{@__config_name}' from database: #{ e.message }"
      end
      
      return nil, nil unless config_in_db
      [ config_in_db[ 'values' ], config_in_db[ 'timestamp' ]]
    end
    
    def save
      
      trying_config = {}
      trying_config[ 'type' ] = @__type
      trying_config[ 'name' ] = @__config_name
      trying_config[ 'timestamp' ] = Time.now
      trying_config[ 'values' ] = @__values
      
      begin
        if @__maintain_history
          @__collection.insert_one trying_config
        else
          @__collection.find_one_and_replace( { 'type' => @__type, 'name' => @__config_name }, trying_config, :upsert => true)
        end
      rescue => e   
        raise e.class, "Problem saving #{ @__type } configuration '#{ @__config_name}' to database: #{ e.message }"
      end
      @__timestamp = trying_config[ 'timestamp' ]
    end
  
    def history
      begin
        configs = @__collection.aggregate( [
           { '$match' => { 'type' => @__type, 'name' => @__config_name } },
           { '$sort'  => { 'timestamp' => 1 }}
         ]).to_a
      rescue => e
        raise e.class, "Problem pulling #{ @__type } configuration history '#{@__config_name}' from database: #{ e.message }"
      end
      configs.collect{ |c| [ c['timestamp'], c['values'] ]}
    end  
    
    def detailed_history
      begin
        historical_configs = history
        historical_configs.collect{ |ts,v| [ ts, self.detailed_validation( v )]}
      end
    end
  end 
end