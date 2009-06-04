#!/usr/bin/env ruby

# should be run from the uzbl-config dir

require 'ftools'

SCRIPT = './scripts/cookies.rb'

ENV['XDG_DATA_HOME'] = './tests/config'
COOKIES_TXT = ENV['XDG_DATA_HOME'] + '/uzbl/cookies.txt'

File.makedirs(ENV['XDG_DATA_HOME'] + '/uzbl')

def PUT url, host, path, k, v, c_path, c_domain
  `#{SCRIPT} ~/.config/uzbl/config 25704 27263009 '' /tmp/uzbl_socket_27263009 #{url} title PUT #{host} #{path} '#{k}=#{v}; expires=Tue, 03-Jun-2008 02:21:32 GMT; path=#{c_path}; domain=#{c_domain}'`
end

def GET url, host, path
  `#{SCRIPT} ~/.config/uzbl/config 25704 27263009 '' /tmp/uzbl_socket_27263009 #{url} title GET #{host} #{path}`
end

def last_line(file)
  ll = nil
  File.open(file) { |f| while tmp = f.gets; ll = tmp; end }
  ll.chomp
end

def assert_equal(a, b)
  unless a == b
    raise "#{a.inspect} != #{b.inspect}"
  end
end

# test PUT 1: simple PUT

File.delete(COOKIES_TXT)

PUT('http://www.uzbl.org/', 'www.uzbl.org', '/wiki/_media/uzbl_webinspector.png',
   'key', 'value', '/wiki/', 'www.uzbl.org')

assert_equal last_line(COOKIES_TXT),
  "www.uzbl.org\tFALSE\t/wiki/\tFALSE\t1212459692\tkey\tvalue"

# test PUT 2: PUT with parent domain should use given domain

File.delete(COOKIES_TXT)

PUT('http://www.uzbl.org/', 'www.uzbl.org', '/wiki/_media/uzbl_webinspector.png',
   'key', 'value', '/wiki/', '.uzbl.org')

assert_equal last_line(COOKIES_TXT),
  "uzbl.org\tFALSE\t/wiki/\tFALSE\t1212459692\tkey\tvalue"

# test PUT 3: PUT with non-parent domain should not use given domain

File.delete(COOKIES_TXT)

PUT('http://www.uzbl.org/', 'www.uzbl.org', '/wiki/_media/uzbl_webinspector.png',
   'key', 'value', '/wiki/', '.notuzbl.example')

assert_equal last_line(COOKIES_TXT),
  "www.uzbl.org\tFALSE\t/wiki/\tFALSE\t1212459692\tkey\tvalue"

# test GET 1: simple get

File.open(COOKIES_TXT, 'w') do |f|
  f.write <<END
uzbl.org\tFALSE\t/wiki/\tFALSE\t1212459692\tkey\tvalue
uzbl.org\tFALSE\t/wiki/_media/\tFALSE\t1212459692\tkey2\tvalue2
END
end

res = GET('http://uzbl.org/', 'uzbl.org', '/wiki/')
assert_equal res, 'key=value'

# test GET 2: get 2 cookies, both for subpaths

res = GET('http://uzbl.org/', 'uzbl.org', '/wiki/_media/uzbl_webinspector.png')
assert_equal res, 'key=value; key2=value2'

# test GET 3: get a cookie for a subpath without cookies

res = GET('http://uzbl.org/', 'uzbl.org', '/other')
assert_equal res, ''

# test GET 4: get a cookie for a subdomain

res = GET('http://www.uzbl.org/', 'www.uzbl.org', '/wiki/')
assert_equal res, 'key=value'

# test GET 5: get a cookie for a domain without cookies

res = GET('http://notuzbl.example/', 'notuzbl.example', '/wiki/')
assert_equal res, ''

puts "success!"
