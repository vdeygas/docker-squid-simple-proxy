#!/bin/bash
set -e

mkdir -p /var/log/squid
chmod -R 755 /var/log/squid
chown -R proxy:proxy /var/log/squid

SQUID_USER=${SQUID_USER}
SQUID_PASS=${SQUID_PASS}

if ( [ -n "${SQUID_USER}" ] && [ -n "${SQUID_PASS}" ] ); then
  # Create a username/password for ncsa_auth.
  htpasswd -c -i -b /etc/squid/.htpasswd ${SQUID_USER} ${SQUID_PASS}

  sed -i "1 i\\
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/.htpasswd\\
auth_param basic children 5\\
auth_param basic realm Squid proxy-caching web server\\
auth_param basic credentialsttl 2 hours\\
auth_param basic casesensitive off" /etc/squid/squid.conf

  sed -i "/http_access deny all/ i\\
acl ncsa_users proxy_auth REQUIRED\\
http_access allow ncsa_users" /etc/squid/squid.conf
else
  sed -i "/http_access deny all/ i http_access allow all" /etc/squid/squid.conf
  sed -i "/http_access deny all/d" /etc/squid/squid.conf
  sed -i "/http_access deny manager/d" /etc/squid/squid.conf
fi

# Forward the squid logs to stdout to assist users of common container
# related tooling (e.g., kubernetes, docker-compose, etc) to access
# the service logs.
tail -F /var/log/squid/access.log 2>/dev/null &
tail -F /var/log/squid/error.log 2>/dev/null &
tail -F /var/log/squid/store.log 2>/dev/null &
tail -F /var/log/squid/cache.log 2>/dev/null &

# Allow arguments to be passed to squid.
if [[ ${1:0:1} = '-' ]]; then
  EXTRA_ARGS="$@"
  set --
elif [[ ${1} == squid || ${1} == $(which squid) ]]; then
  EXTRA_ARGS="${@:2}"
  set --
fi

# Default behaviour is to launch squid.
if [[ -z ${1} ]]; then
  echo "Starting squid..."
  exec $(which squid) -f /etc/squid/squid.conf -NYCd 1 ${EXTRA_ARGS}
else
  exec "$@"
fi
