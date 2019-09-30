#!/bin/sh
set -e

if test "$DEBUG"; then
    set -x
fi

echo Starting Nexus.
echo "$(date) - LDAP Enabled: $LDAP_ENABLED"

if ! test -s $NEXUS_DATA/current_local_password; then
    echo admin123 >$NEXUS_DATA/current_local_password
fi

echo Executing provision.sh
nohup /usr/local/bin/provision.sh &

exec $@
