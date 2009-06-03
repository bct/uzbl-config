#!/bin/bash
# this is an example script of how you could manage your cookies.

if [ -f /usr/share/uzbl/examples/configs/cookies ]
then
	file=/usr/share/uzbl/examples/configs/cookies
else
	file=./examples/configs/cookies #useful when developing
fi

# this expands to ~/.local/share/uzbl/cookies.txt where XDH is set,
# and breaks everywhere else. you might also have to create the directory.
cookie_file=$XDG_DATA_HOME/uzbl/cookies.txt

# you probably want your cookies config file in your $XDG_CONFIG_HOME ( eg $HOME/.config/uzbl/cookies)

# Note. in uzbl there is no strict definition on what a session is.  it's YOUR job to clear cookies marked as end_session if you want to keep cookies only valid during a "session"

# MAYBE TODO: allow user to edit cookie before saving. this cannot be done with zenity :(
# TODO: different cookie paths per config (eg per group of uzbl instances)

# TODO: correct implementation.
# see http://curl.haxx.se/rfc/cookie_spec.html
# http://en.wikipedia.org/wiki/HTTP_cookie

# TODO:
# - check expires= before sending.
# - write sample script that cleans up cookies dir based on expires attribute.
# - check uri against domain attribute. and path also.
# - implement secure attribute.
# - support blocking or not for 3rd parties
# - http://kb.mozillazine.org/Cookies.txt
# - don't always append cookies, sometimes we need to overwrite

# uri=$6
# uri=${uri/http:\/\/} # strip 'http://' part
# host=${uri/\/*/}
action=$8 # GET/PUT
host=$9
shift
path=$9
shift
cookie=$9

field_domain=$host
field_path=$path
field_name=
field_value=
field_exp='end_session'

# Example cookie:
# test_cookie=CheckForPermission; expires=Thu, 07-May-2009 19:17:55 GMT; path=/; domain=.doubleclick.net

function parse_cookie () {
  echo "parsing $cookie" >> $HOME/cookie.log
	IFS=$';'
	first_pair=1
	for pair in $cookie
	do
		if [ "$first_pair" == 1 ]
		then
			field_name=${pair%%=*}
			field_value=${pair#*=}
			first_pair=0
		else
			IFS=' ' read -r pair <<< "$pair" # strip leading/trailing white space

			key=${pair%%=*}
			val=${pair#*=}

			[ "$key" == expires ] && field_exp=`date -u -d "$val" +'%s'`
			[ "$key" == path ] && field_path=$val

      if [ "$key" == domain -a ${val:0:1} == "." ]
      then # $val must begin with a . so that we don't match eu.example to aoeu.example
        # get the number of .s in the given domain (non-consecutive and not at
        # the end of the line), +1 for the newline
        len=$(echo $val | sed -e 's/\.\.*/\./g' -e 's/\.$//' -e 's/[^\.]//g' | wc -c)

        if [ $len -gt 2 -a ${host%%$val} != ${host} ]
        then # the given domain is a suffix of our real domain, and it has
             # more than one . (so they didn't try to use e.g. .com), let's use it
          field_domain=${val#.}
        fi
      fi
		fi
	done
	unset IFS
}

# match cookies in cookies.txt against hostname and path
function get_cookie () {
  echo 'get_cookie' >> $HOME/cookie.log
	path_esc=${path//\//\\/}

  hostpattern='echo $host | sed 's/'
	cookie=`grep "/^[^\t]*$host\t[^\t]*\t$path_esc/" $cookie_file | tail -n 1 | cut -f 3,6-`

	if [ -z "$cookie" ]
	then
		false
	else
		read domain alow_read_other_subdomains path http_required expiration name value <<< "$cookie"
		cookie="$name=$value"
		true
	fi
}

# we use the cookies.txt format (See http://kb.mozillazine.org/Cookies.txt)
# This is one textfile with entries like this:
# kb.mozillazine.org	FALSE	/	FALSE	1146030396	wikiUserID	16993
# domain allow-read-other-subdomains path http-required expiration name value

function write_cookie () {
  # TODO: replace matching lines if they exist
  echo -e "$field_domain\tFALSE\t$field_path\tFALSE\t$field_exp\t$field_name\t$field_value" >> $cookie_file
}

[ $action == PUT ] && parse_cookie && write_cookie
[ $action == GET ] && get_cookie && echo "$cookie"
