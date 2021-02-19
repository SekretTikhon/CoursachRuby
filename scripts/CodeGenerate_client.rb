#!/usr/bin/env ruby

require 'socket'
include Socket::Constants

url = "http://localhost:4567"

print "Waiting for connection..."
sock = UNIXSocket.open("\0(take code socket)")
print " Connect.\n"

print "Send info about this user.\n"
sock.setsockopt(SOL_SOCKET, SO_PASSCRED, 1)

print "Waiting to receive message..."
code = sock.recv(255)
print " Received.\n"

print "Your code: #{code}\nUse it when you login.\nOr follow this link: #{url}/login?code=#{code}\n"
