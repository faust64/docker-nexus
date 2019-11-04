#!/bin/sh
set -e

if test "$DEBUG"; then
    set -x
fi

NEXUS_TRUST_STORE="${NEXUS_TRUST_STORE:-/nexus-data/trusted.jks}"
NEXUS_TRUST_STORE_PASS="${NEXUS_TRUST_STORE_PASS:-changeit}"
INSTALL4J_ADD_VM_PARAMS="$INSTALL4J_ADD_VM_PARAMS -Djavax.net.ssl.trustStore=$NEXUS_TRUST_STORE -Djavax.net.ssl.trustStorePassword=$NEXUS_TRUST_STORE_PASS"

if ! test -s "$NEXUS_TRUST_STORE"; then
    echo Provision Keystore
    mkdir -p $(dirname "$NEXUS_TRUST_STORE")
    count=0
    for ca in /run/secrets/kubernetes.io/serviceaccount/service-ca.crt \
        /etc/ssl/certs/ca-bundle*crt \
	/certs/*.crt
    do
	if ! test -s "$ca"; then
	    continue
	fi
	old=0
	grep -n 'END CERTIFICATE' "$ca"  | awk -F: '{print $1}' \
	    | while read stop
	    do
		count=`expr $count + 1`
		echo "Processing $ca (#$count)"
		head -$stop "$ca" | tail -`expr $stop - $old` >/tmp/insert.crt
		keytool -import -trustcacerts -alias inter$count \
		    -file /tmp/insert.crt -keystore "$NEXUS_TRUST_STORE" \
		    -storepass "$NEXUS_TRUST_STORE_PASS" -noprompt
		old=$stop
	    done
	echo done with "$ca"
    done
    rm -f /tmp/insert.crt
    unset count old
fi

echo Starting Nexus
echo "$(date) - LDAP Enabled: $LDAP_ENABLED"

if ! test -s $NEXUS_DATA/current_local_password; then
    echo admin123 >$NEXUS_DATA/current_local_password
fi

echo Executing provision.sh
/usr/local/bin/provision.sh &

exec $@
