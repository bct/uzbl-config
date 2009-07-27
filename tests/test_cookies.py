#!/usr/bin/env python

import sys
import socket

import unittest
import random
import string

socket_path = "/tmp/uzbl-cookie-socket"

class TestCookies(unittest.TestCase):
  def connect(self):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_SEQPACKET)
    s.connect(socket_path)
    return s

  def GET(self, scheme, host, path):
    s = self.connect()

    cmd = "\0".join(("GET",scheme,host,path))
    s.send(cmd)

    res = s.recv(2**16)

    s.close()

    return res

  def PUT(self, scheme, host, path, cookie):
    s = self.connect()

    cmd = "\0".join(("PUT",scheme,host,path,cookie))
    s.send(cmd)

    s.close()

  def random_host(self):
    return ''.join([random.choice(string.lowercase) for x in xrange(8)]) + ".example.org"

  def make_cookie(self, name, value, path=None, domain=None):
    str = "%s=%s" % (name, value)

    if path:
      str += ("; path=%s" % (path))

    if domain:
      str += ("; domain=%s" % (domain))

    return str

  def assertCookieExists(self, host, path, value="testValue"):
    res = self.GET("http", host, path)
    self.assertEqual(res, "testKey="+value)

  def assertCookieDoesNotExist(self, host, path):
    res = self.GET("http", host, path)
    self.assertEqual(res, '')

  def test_simple(self):
    '''when only name and value are specified, you should get a session cookie
    that is only valid for the requested domain and path'''

    host = self.random_host()
    ck = self.make_cookie("testKey", "testValue")

    self.PUT("http", host, "/wiki/", ck)

    self.assertCookieExists(host, "/wiki/")
    self.assertCookieExists(host, "/wiki/some-subpath")

    self.assertCookieDoesNotExist(host, "/wiki")
    self.assertCookieDoesNotExist(host, "/")
    self.assertCookieDoesNotExist(host, "/something-else")

    some_other_host = self.random_host()
    self.assertCookieDoesNotExist(some_other_host, "/wiki/")

  def test_cross_subdomain_valid(self):
    '''when a valid parent domain is given in the cookie, the cookie should be
    available to other children of the domain.'''

    parent_domain = self.random_host()
    subdomain1 = 'xxx.' + parent_domain
    subdomain2 = 'yyy.' + parent_domain

    ck = self.make_cookie("testKey", "testValue", domain='.'+parent_domain)

    self.PUT("http", subdomain1, "/wiki/", ck)

    self.assertCookieExists(subdomain1, "/wiki/")
    self.assertCookieExists(subdomain1, "/wiki/")

    some_other_domain = self.random_host()
    self.assertCookieDoesNotExist(some_other_domain, "/wiki/")

  def test_cross_subdomain_invalid(self):
    '''when an invalid parent domain is given in the cookie, the cookie should
    only be available to the domain that was originally requested.'''
    host = self.random_host()
    some_other_subdomain = self.random_host()

    ck = self.make_cookie("testKey", "testValue", domain='.'+some_other_subdomain)
    self.PUT("http", host, "/wiki", ck)

    self.assertCookieExists(host, "/wiki/")
    self.assertCookieDoesNotExist(some_other_subdomain, "/wiki/")

    ck = self.make_cookie("testKey", "testValue", domain='.org')
    self.PUT("http", host, "/wiki", ck)

    self.assertCookieExists(host, "/wiki/")
    self.assertCookieDoesNotExist(some_other_subdomain, "/wiki/")

  def test_replace_cookie(self):
    host = self.random_host()
    ck = self.make_cookie("testKey", "testValue")

    self.PUT("http", host, "/wiki/", ck)
    self.assertCookieExists(host, "/wiki/")

    ck = self.make_cookie("testKey", "newValue")

    self.PUT("http", host, "/wiki/", ck)
    self.assertCookieExists(host, "/wiki/", "newValue")

  def test_get_multiple_cookies(self):
    host = self.random_host()
    ck1 = self.make_cookie("k1", "v1")
    ck2 = self.make_cookie("k2", "v2")

    self.PUT("http", host, "/", ck1)
    self.PUT("http", host, "/", ck2)

    res = self.GET("http", host, "/")

    cks = [x.strip() for x in res.split(";")]
    self.assertEqual(cks[0], "k1=v1")
    self.assertEqual(cks[1], "k2=v2")

if __name__ == '__main__':
  unittest.main()
