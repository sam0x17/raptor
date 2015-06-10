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
      begin
        RAPTOR::Database.init_tables_and_models
        puts "initialized samples table"
      rescue => e
        raise e
      end
      true
    end

    def self.clear_data
      RAPTOR::Sample.delete_all
      ActiveRecord::Base.connection.reset_pk_sequence!(RAPTOR::Sample.table_name)
      true
    end

    def self.reset_db
      ActiveRecord::Migration.drop_table(:samples)
      begin
        RAPTOR::Database.init_tables_and_models
      rescue
      end
      RAPTOR::Database.init_tables_and_models
      true
    end

    def self.init_tables_and_models
      if !ActiveRecord::Base.connection.table_exists? :samples
        ActiveRecord::Schema.define do
          create_table :samples do |t|
            t.integer :x, null: false
            t.integer :y, null: false
            t.integer :color, null: false
            t.integer :rx, null: false
            t.integer :ry, null: false
            t.integer :rz, null: false
            t.float :probability, default: 0.0, index: true
            t.integer :count, default: 0, index: true
          end
          add_index "samples_pos_index".to_sym, [:rx, :ry]
        end
      end
      eval("require 'raptor/sample'", TOPLEVEL_BINDING)
      true
    end

  end
end
