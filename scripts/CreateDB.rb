#!/usr/bin/ruby

require 'sqlite3'
require 'config'

def create_table
	columns = []
	Settings.db.table.columns.each do |elem|
		columns << "#{elem.name} #{elem.type}"
	end
	@db.execute "CREATE TABLE IF NOT EXISTS #{Settings.db.table.name}(#{columns.join(", ")})"
end

if ARGV.length == 1
	config_path = ARGV[0]
	Config.load_and_set_settings(config_path)

	@db_path = Settings.db.path
	if !File.exist?(@db_path)
		db_dir = Pathname.new(@db_path).dirname
		if !File.exist?(db_dir)
			Dir.mkdir(db_dir)
		end
		SQLite3::Database.new @db_path
		@db = SQLite3::Database.open @db_path
		
		create_table
		
		@db.close if @db
		puts "Database succesfully created."
	else
		puts 'Database already exists.'
	end

else
	puts "Need 1 arg: path to config"
end



