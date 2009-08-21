#!/usr/bin/env ruby

require 'socket'
include Socket::Constants

# this expands to ~/.local/share/uzbl/session where XDH is set,
# (and breaks everywhere else). you might also have to create the directory.
SESSION_FILE = ENV['XDG_DATA_HOME'] + '/uzbl/session'

File.open(SESSION_FILE, 'w') do |f|
  socket_paths = Dir['/tmp/uzbl_socket*']
  socket_paths.each do |socket_path|
    socket = Socket.new(AF_UNIX, SOCK_STREAM, 0)

    sockaddr = Socket.pack_sockaddr_un(socket_path)
    socket.connect(sockaddr)

    socket.puts 'print @uri'
    f.puts(socket.readline().chomp)

    socket.close
  end
end
