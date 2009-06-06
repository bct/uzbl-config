#!/usr/bin/env ruby

# this is a script for managing cookies with uzbl.
# it does not prompt you to accept cookies, because i'm not *that* paranoid.

# it is mostly ported from the cookies.sh included with uzbl.
# i would have preferred to stick with bash but it is a Bad Language.

# this expands to ~/.local/share/uzbl/cookies.txt where XDH is set,
# and breaks everywhere else. you might also have to create the directory.
$cookie_file = ENV['XDG_DATA_HOME'] + '/uzbl/cookies.txt'

# Note. in uzbl there is no strict definition on what a session is.  it's
# YOUR job to clear cookies marked as end_session if you want to keep cookies
# only valid during a "session"

# TODO: different cookie paths per config (eg per group of uzbl instances)

# references:
# - http://curl.haxx.se/rfc/cookie_spec.html
# - http://en.wikipedia.org/wiki/HTTP_cookie

# TODO:
# - check expires= before sending.
# - write sample script that cleans up cookies dir based on expires attribute.
# - check uri against domain attribute. and path also.
# - implement secure attribute.
# - support blocking or not for 3rd parties
# - http://kb.mozillazine.org/Cookies.txt
# - don't always append cookies, sometimes we need to overwrite

COOKIES_TXT = ENV['XDG_DATA_HOME'] + '/uzbl/cookies.txt'

def get_cookies(cookie_file, host, path)
  pairs = []

  open(cookie_file, 'r') do |f|
    f.each do |line|
      fields = line.chomp.split "\t"

      f_host, f_path, key, value = fields[0], fields[2], fields[5], fields[6]

      # check if this line is for this domain or a parent of it
      next unless host.match(/^.*#{Regexp.escape(f_host)}$/)

      # check if this line is for this path or a parent of it
      next unless path.match(/^#{Regexp.escape(f_path)}/)

      # ok, let's include the cookie in our request
      pairs << "#{key}=#{value}"
    end
  end

  pairs.join '; '
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

  action = ARGV[7]
  host = ARGV[8]
  path = ARGV[9]
  cookie = ARGV[10]

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
