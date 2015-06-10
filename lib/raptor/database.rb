require 'active_record'
require 'uri'
module RAPTOR
  module Database

    def self.create_db
      ActiveRecord::Base.establish_connection adapter: 'postgresql',
                                              username: @@db['username'],
                                              password: @@db['password'],
                                              database: 'postgres'
      ActiveRecord::Base.connection.create_database @@db['db_name']
      true
    end

    def self.load_db_config
      @@db = YAML.load(File.read('config/database.yml'))['database']
      begin
        RAPTOR::Database.create_db
        puts "created RAPTOR PostgreSQL database ('#{@@db['db_name']}')"
      rescue ActiveRecord::StatementInvalid => e
        puts "connected to RAPTOR PostgreSQL database ('#{@@db['db_name']}')"
      end
      ActiveRecord::Migration.execute('CREATE EXTENSION IF NOT EXISTS hstore')
      begin
        RAPTOR::Database.init_tables_and_models
        puts "initialized samples table"
      rescue => e
        raise e
      end
      true
    end

    def self.clear_data
      RAPTOR::Activation.delete_all
      ActiveRecord::Base.connection.reset_pk_sequence!(RAPTOR::Activation.table_name)
      true
    end

    def self.reset_db
      ActiveRecord::Migration.drop_table(:activations)
      ActiveRecord::Migration.execute('CREATE EXTENSION IF NOT EXISTS hstore')
      begin
        RAPTOR::Database.init_tables_and_models
      rescue
      end
      RAPTOR::Database.init_tables_and_models
      true
    end

    def self.init_tables_and_models
      if !ActiveRecord::Base.connection.table_exists? :activations
        ActiveRecord::Schema.define do
          create_table :activations do |t|
            t.integer :x, limit: 2, null: false
            t.integer :y, limit: 2, null: false
            t.integer :color, limit: 8, null: false
            t.hstore :data, default: {}
          end
          add_index "activations_pos_lookup_index".to_sym, [:x, :y, :color], unique: true
        end
      end
      eval("require 'raptor/activation'", TOPLEVEL_BINDING)
      true
    end

  end
end
