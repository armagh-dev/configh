

require_relative './base_configuration'

module Configh
  
  class UnrecognizedTypeError < StandardError; end
  class UndefinedCollectionError < StandardError; end
  
  class MongoBasedConfiguration < PersistedConfiguration
  
    def self.initialize_from_named_config( collection, name = 'default', maintain_history: false, using_values: nil )
      mbc = new( collection, name, maintain_history )
      if using_values
        mbc.reset_values_to( using_values )
        mbc.save
      else
        mbc.load_named_config
      end
      mbc
    end
    
    def self.initialize_from_static_values( values_hash )
      mbc = new( nil, nil, false )
      mbc.reset_values_to( values_hash )
      mbc
    end
  
    def self.named_configs( collection, include_descendants: true )
      
      raise UndefinedCollectionError, "collection passed to named_configs cannot be nil" unless collection
      
      conf_class = const_get( 'CONFIGURED_CLASS' )
      types_to_find = [ conf_class.name ]
      
      if include_descendants
        types_to_find.concat ObjectSpace.each_object( Class ).select{ |klass| klass < conf_class }.collect{ |k| k.name }
      end
      
      configs_by_name = {}
      collection.aggregate( [
        { '$match' => { 'type' => { '$in' => types_to_find }}},
        { '$sort'  => { 'timstamp' => -1 }}
      ]).each do |config_in_db|
        configs_by_name[ config_in_db[ 'name' ]] ||= config_in_db
      end
      
      Enumerator.new do |yielder|
        configs_by_name.each do |config_name, config|
          configured_class = nil
          begin
            configured_class = eval( config[ 'type' ])
          rescue => e
            raise UnrecognizedTypeError, "Unrecognized action class in workflow configuration: #{ config[ 'type']}"
          end
          yielder << [ configured_class, configured_class.use_named_config( collection, config_name ) ]
        end
      end
    end
    
    def initialize( collection, name=nil, maintain_history=false )
      raise UndefinedCollectionError, "collection passed to new cannot be nil" if (name and not collection)
      
      raise "Name must be specified if collection is given" if ( collection and not name )
      super( name )
      @__collection = collection
      @__maintain_history = maintain_history
    end
     
    def get
      begin
        config_in_db = @__collection.aggregate( [
           { '$match' => { 'type' => @__type, 'name' => @__name } },
           { '$sort'  => { 'timestamp' => -1 }},
           { '$limit' => 1 }
         ]).first
      rescue => e
        raise e.class, "Problem pulling #{ @__type } configuration '#{@__name}' from database: #{ e.message }"
      end
      
      return nil, nil unless config_in_db
      [ config_in_db[ 'values' ], config_in_db[ 'timestamp' ]]
    end
    
    def save
      
      trying_config = {}
      trying_config[ 'type' ]      = @__type
      trying_config[ 'name' ]      = @__name
      trying_config[ 'timestamp' ] = Time.now
      trying_config[ 'values' ]    = @__values
      
      begin
        if @__maintain_history
          @__collection.insert_one trying_config
        else
          @__collection.find_one_and_replace( { 'type' => @__type, 'name' => @__name }, trying_config, :upsert => true)
        end
      rescue => e   
        raise e.class, "Problem saving #{ @__type } configuration '#{ @__name}' to database: #{ e.message }"
      end
      @__timestamp = trying_config[ 'timestamp' ]
    end
  
    def history
      begin
        configs = @__collection.aggregate( [
           { '$match' => { 'type' => @__type, 'name' => @__name } },
           { '$sort'  => { 'timestamp' => 1 }}
         ]).to_a
      rescue => e
        raise e.class, "Problem pulling #{ @__type } configuration history '#{@__name}' from database: #{ e.message }"
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