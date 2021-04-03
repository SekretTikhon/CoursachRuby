#!/usr/bin/env ruby

require 'securerandom'
require 'sqlite3'
require 'config'
require 'socket'
include Socket::Constants

def insert_row row
	db = SQLite3::Database.open Settings.db.path
	comand = "INSERT INTO %s VALUES %s" % [Settings.db.table.name, row]
	db.execute comand
	db.close if db
end

if ARGV.length == 0
  print "Uses default config: "
  config_path = "./config/settings.yml"
elsif ARGV.length == 1
  print "Uses custom config: "
	config_path = ARGV[0]
else
  print "help todo"
  exit 1
end
print "#{config_path}\n"
Config.load_and_set_settings(config_path)

@socket_addr = Settings.socket.addr
@socket_addr[0] = "\0"

print "Open UNIXServer..."
server = UNIXServer.open(@socket_addr)
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
  valid_until = generated + Settings.code.valid_time
  row = "('#{user}', '#{code}', #{generated}, #{valid_until}, 0)"
  insert_row row
  print " Done.\n"

  print "Send code to client.\n"
  sock.send "#{Settings.base_url}\n#{code}", 0
  print "End of connection.\n"

end
