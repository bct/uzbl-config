#!/usr/bin/env ruby

# this expands to ~/.local/share/uzbl/cookies.txt where XDH is set,
# (and breaks everywhere else). you might also have to create the directory.
COOKIES_TXT = ENV['XDG_DATA_HOME'] + '/uzbl/cookies.txt'

require 'set'

class CookieThingy
  def initialize cookies_txt
    @hosts = Set.new
    @host_paths = {}

    load_file cookies_txt
  end

  def load_file cookies_txt
    open(cookies_txt, 'r') do |f|
      f.each do |line|
        fields = line.chomp.split "\t"
        f_host, f_path, key, value = fields[0], fields[2], fields[5], fields[6]

        @hosts                        << f_host
        @host_paths[f_host]           ||= {}
        @host_paths[f_host][f_path]   ||= []
        @host_paths[f_host][f_path]   << "#{key}=#{value}"
      end
    end
  end

  def get host, path
    cookies = []

    matching_hosts = @hosts.find_all do |h|
      host.match /^.*#{Regexp.escape(h)}$/
    end

    matching_hosts.each do |h|
      @host_paths[h].each do |k,v|
        cookies += v if path.match /^#{Regexp.escape(k)}/
      end
    end

    cookies.empty? ? 'x' : cookies.join('; ')
  end
end

COOKIES = CookieThingy.new COOKIES_TXT

def handle_req data
  cmd,rest = data.split(/ /, 2)

  if cmd == 'GET'
    rest.match /'([^']*)' '([^']*)' '([^']*)'/
    scheme, host, path          = $1, $2, $3

    COOKIES.get host, path
  elsif cmd == 'PUT'
    rest.match /'([^']*)' '([^']*)' '([^']*)' '([^']*)'/
    scheme, host, path, cookie  = $1, $2, $3, $4
  end
end

require 'socket'
include Socket::Constants

socket = Socket.new(AF_UNIX, SOCK_SEQPACKET, 0)
sockaddr = Socket.pack_sockaddr_un("/tmp/uzbl-cookie-socket")
socket.bind(sockaddr)
socket.listen(1)

conns = [socket]

loop do
  r,w,e = IO.select(conns)

  r.each do |c|
    if c == socket
      # new connection
      new_conn, str = socket.accept
      conns << new_conn
    else
      # activity on a connection
      data, rest = c.recvfrom(2**16)

      if data.empty?
        # connection closed
        conns -= [c]
      else
        p data
        c.write handle_req(data)
      end
    end
  end
end

exit

# this is a script for managing cookies with uzbl.
# it does not prompt you to accept cookies, because i'm not *that* paranoid.

# it is mostly ported from the cookies.sh included with uzbl.
# i would have preferred to stick with bash but it is a Bad Language.

# if this is 'true' then when you visit http://example.org/ cookies will be
# sent when uzbl requests http://advertising.example/image.jpg that was
# embedded on that page
SEND_THIRD_PARTY_COOKIES = false

# Note. in uzbl there is no strict definition on what a session is.  it's
# YOUR job to clear cookies marked as end_session if you want to keep cookies
# only valid during a "session"

# references:
# - http://curl.haxx.se/rfc/cookie_spec.html
# - http://en.wikipedia.org/wiki/HTTP_cookie

# TODO:
# - check expires= before sending.
# - write sample script that cleans up cookies dir based on expires attribute.
# - implement secure attribute.
# - http://kb.mozillazine.org/Cookies.txt
# - figure out how to handle cross-domain cookies and third party cookies in
#   really big url spaces like .co.uk

def get_cookies(cookie_file, host, path)
end

def put_cookie(cookie_file, domain, read_other, path, secure, exp, key, value)
  if File.exists? cookie_file
    cookies = File.readlines(cookie_file)
  else
    cookies = []
  end

  newcookie = "#{domain}\tFALSE\t#{path}\tFALSE\t#{exp}\t#{key}\t#{value}"
  done = false

  open(cookie_file, 'w') do |f|
    cookies.each do |line|
      fields = line.chomp.split "\t"
      l_host, l_path, l_key = fields[0], fields[2], fields[5]

      if not done and l_host == domain and l_path == path and l_key == key
        # this is the line, replace the existing cookie
        f.puts newcookie
        done = true
      else
        # this is not the line, or we already wrote a line
        # just copy the existing line out
        f.puts line
      end
    end

    if not done
      # it must be a new cookie, add it to the end of the file
      f.puts newcookie
    end
  end
end

if $0 == __FILE__
  require 'time'
  require 'uri'

  req_host = URI.parse(URI.escape(ARGV[5])).host
  action = ARGV[7]
  host = ARGV[9]
  path = ARGV[10]
  cookie = ARGV[11]

=begin
  unless SEND_THIRD_PARTY_COOKIES or
    $stderr.puts req_host.inspect
    $stderr.puts host.inspect
    (req_host.split('.')[-2,2] == host.split('.')[-2,2])
    File.open('/home/bct/cookies-debug.txt', 'a') do |f|
      f.puts "exiting " + req_host.split('.')[-2,2].inspect + " " + host.split('.')[-2,2].inspect
    end
    exit
  end
=end

  if action == 'PUT'
    crumbs = cookie.split(';').map { |p| p.strip.split('=', 2) }
    key,value = crumbs.first

    exp = 'session'
    domain = host

    crumbs[1..-1].each do |k,v|
      if k == 'expires'
        exp = Time.parse(v).to_i
      elsif k == 'path'
        path = v
      elsif k == 'domain' and v[0].chr == '.'
        # the domain they give us has to begin with a . so that we aren't
        # tempted to count eu.example as a match for aoeu.example.

        v.gsub!(/\.\.*/, '.') # remove consecutive .s

        # count the number of .s that aren't at the end of the domain
        num_dots = v.gsub(/\.$/, '').gsub(/[^\.]/, '').length

        if num_dots > 1 and host.match /#{Regexp.escape(v)}$/
          # the given domain is a suffix of our real domain and it has more
          # than one . so they didn't try to use e.g. .com. Nothing looks
          # funny here, let's use it (but strip the leading . first)!
          domain = v[1..-1]
        end
      end
    end

    put_cookie(COOKIES_TXT, domain, false, path, false, exp, key, value)
  elsif action == 'GET'
    puts get_cookies(COOKIES_TXT, host, path)
  end
end
