#!/usr/bin/ruby

require 'sqlite3'

@table_name = 'Codes'

def insert_row row
	@db.execute "INSERT INTO #{@table_name} VALUES #{row}"
end

def create_table
	@db.execute "
		CREATE TABLE IF NOT EXISTS #{@table_name}(
			user TEXT,
			code TEXT,
			generated INTEGER,
			valid_until INTEGER,
			already_used INTEGER
		)"
end

if ARGV.length == 1
	@db_path = ARGV[0]

	SQLite3::Database.new @db_path
	@db = SQLite3::Database.open @db_path
	
	create_table
	
	insert_row "('tikhon', 'key', 1, 9223372036854775807, 0)"
	insert_row "('user1', 'user1key', 1, 9223372036854775807, 0)"

	@db.close if @db
	puts "Success!"

elsif
	puts "need 1 arg: db_path"
end



