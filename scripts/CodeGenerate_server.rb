#!/usr/bin/env ruby

require 'securerandom'
require 'sqlite3'
require 'socket'
include Socket::Constants

@code_valid_time = 24*60*60 #1 day
@db_codes_db_path = './db/base.db'
@db_codes_table_name = 'Codes'

def insert_row row
	db = SQLite3::Database.open @db_codes_db_path
	comand = "INSERT INTO %s VALUES %s" % [@db_codes_table_name, row]
	db.execute comand
	db.close if db
end

print "Open UNIXServer..."
server = UNIXServer.open("\0(take code socket)")
print "Done\n"

while true
  print "\nConnect with user..."
  sock = server.accept
  print " Done.\n"

  print "Receive info about the user..."
  opt  = sock.getsockopt(SOL_SOCKET, SO_PEERCRED)
  print " Done.\n"
  pid, uid, gid = opt.unpack("i3")

  print "Determined user: "
  user = (`getent passwd #{uid}`).split(":")[0]
  print "#{user}\n"

  print "Generated code: "
  code = SecureRandom.urlsafe_base64
  print "#{code}\n"

  print "Insert row to db..."
  generated = `date +%s`.to_i
  valid_until = generated + @code_valid_time
  row = "('#{user}', '#{code}', #{generated}, #{valid_until}, 0)"
  insert_row row
  print " Done.\n"

  print "Send code to client.\n"
  sock.send code, 0
  print "End of connection.\n"

end
