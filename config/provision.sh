#!/bin/bash

if test "$DEBUG"; then
    set -x
fi

OPENLDAP_BIND_DN_PREFIX="${OPENLDAP_BIND_DN_PREFIX:-cn=nexus,ou=services}"
OPENLDAP_BIND_PW="${OPENLDAP_BIND_PW:-}"
OPENLDAP_DOMAIN=${OPENLDAP_DOMAIN:-demo.local}
OPENLDAP_HOST=${OPENLDAP_HOST:-127.0.0.1}
OPENLDAP_PROTO=${OPENLDAP_PROTO:-ldap}
OPENLDAP_USERS_OBJECTCLASS=${OPENLDAP_USERS_OBJECTCLASS:-inetOrgPerson}
if test -z "$OPENLDAP_BASE"; then
    OPENLDAP_BASE=`echo "dc=$OPENLDAP_DOMAIN" | sed 's|\.|,dc=|g'`
fi
if test -z "$OPENLDAP_GROUP_MAPPINGS"; then
    OPENLDAP_GROUP_MAPPINGS="Admins,nx-admin All,nx-anonymous"
fi
if test -z "$OPENLDAP_PORT" -a "$OPENLDAP_PROTO" = ldaps; then
    OPENLDAP_PORT=636
elif test -z "$OPENLDAP_PORT"; then
    OPENLDAP_PORT=389
fi
if ! test -s $NEXUS_DATA/current_local_password -o \
	-s $NEXUS_DATA/admin.password; then
    echo "[ERR] Current admin password not found."
    exit 1
fi

function getPassword()
{
    if test -s $NEXUS_DATA/admin.password; then
	f=$NEXUS_DATA/admin.password
    else
	f=$NEXUS_DATA/current_local_password
    fi
    head -1 $f | tr -d '\n'
}

pretty_sleep()
{
    secs=${1:-60}
    tool=${2:-'service'}
    while test "$secs" -gt 0
    do
	echo -ne "$tool unavailable, sleeping for: $secs\033[0Ks\r"
	sleep 1
	secs=`expr $secs - 1`
    done
}

echo "* Waiting for the Nexus3 to become available - this can take a few minutes"
cpt=0
if test "$NEXUS_CONTEXT" -a "$NEXUS_CONTEXT" != /; then
    nexus_host=http://localhost:8081/$NEXUS_CONTEXT
else
    nexus_host=http://localhost:8081
fi
username=admin
password="`getPassword`"
while ! curl -I -s -u "$username:$password" "$nexus_host/" | head -n 1 | cut -d$' ' -f2 | grep 200 >/dev/null
do
    test "$cpt" -ge 60 && break
    pretty_sleep 10 Nexus3
    cpt=`expr $cpt + 1`
done
if ! curl -I -s -u "$username:$password" "$nexus_host/" | head -n 1 | cut -d$' ' -f2 | grep 200 >/dev/null; then
    echo bailing out
    exit 1
fi

password="`getPassword`"

function addAndRunScript()
{
    name=$1
    file=$2
    eval args="${3:-false}"
    content=$(</$file)
    if jq -n -c --arg name "$name" --arg content "$content" \
	'{name: $name, content: $content, type: "groovy"}' \
	| curl -v -X POST -u "$username":"$password" \
	    --header "Content-Type: application/json" \
	    "$nexus_host/service/rest/v1/script" -d@-; then
	printf "\nPublished $file as $name\n\n"
	if curl -v -X POST -u "$username":"$password" \
	    --header "Content-Type: text/plain" \
	    "$nexus_host/service/rest/v1/script/$name/run" \
	    -d "$args"; then
	    printf "\nSuccessfully executed $name script\n\n\n"
	else
	    printf "\nFailed executing $name script\n\n\n"
	fi
    else
	printf "\nFailed publishing $file as $name\n\n"
    fi
}

cat <<EOF
 == Provisioning Scripts Starting ==

Executing on $nexus_host
EOF

#if test "$NEXUS_PROXY_HOST"; then
#    NEXUS_PROXY_PORT=${NEXUS_PROXY_HOST:-3128}
#    echo " -- Setting Proxy Host: $NEXUS_PROXY_HOST:$NEXUS_PROXY_PORT"
#    remoteProxyArg=$(jq -n -c --arg host "$NEXUS_PROXY_HOST" --arg port "$NEXUS_PROXY_PORT" '{with_http_proxy: "true", http_proxy_host: $host, http_proxy_port: $port}')
#    addAndRunScript remoteProxy resources/conf/setup_http_proxy.groovy "\$remoteProxyArg"
#fi

if test "$OPENLDAP_BIND_PW" -a ! -s $NEXUS_DATA/ldap.configured; then
    if (
	    echo "{\"id\":\"\",\"name\":\"Kube\","
	    echo "\"protocol\":\"$OPENLDAP_PROTO\","
	    echo "\"host\":\"$OPENLDAP_HOST\","
	    echo "\"port\":\"$OPENLDAP_PORT\","
	    echo "\"searchBase\":\"$OPENLDAP_BASE\","
	    echo '"authScheme":"simple","userBaseDn":"ou=users",'
	    echo "\"authUsername\":\"$OPENLDAP_BIND_DN_PREFIX,$OPENLDAP_BASE\","
	    echo '"userSubtree":true,"userIdAttribute":"uid",'
	    echo "\"authPassword\":\"$OPENLDAP_BIND_PW\","
	    echo "\"connectionTimeout\":\"30\","
	    echo "\"ldapGroupsAsRoles\":true,"
	    echo "\"connectionRetryDelay\":\"300\","
	    echo "\"maxIncidentsCount\":\"3\","
	    echo '"template":"Generic Ldap Server",'
	    echo "\"userObjectClass\":\"$OPENLDAP_USERS_OBJECTCLASS\","
	    echo '"userLdapFilter":"(!(pwdAccountLockedTime=*))",'
	    echo '"userRealNameAttribute":"cn",'
	    echo '"userEmailAddressAttribute":"mail",'
	    echo '"userPasswordAttribute":"","groupType":"dynamic",'
	    echo '"userMemberOfAttribute":"memberOf",'
	    echo '"connectionTimeoutSeconds":"30",'
	    echo '"connectionRetryDelaySeconds":"300"}'
	) | curl --header 'Content-Type: application/json' \
	    --header 'Accept: application/json' -X POST -u "admin:$password" \
	    -s -o /dev/null -w '%{http_code}' \
	    $nexus_host/service/rest/beta/security/ldap -d@- \
	  | grep ^201 >/dev/null; then
	echo successfully configured LDAP backend
	echo "$(date +%s) initialized" >$NEXUS_DATA/ldap.configured
    else
	echo failed provisionning LDAP auth backend
    fi
    for mapping in $OPENLDAP_GROUP_MAPPINGS
    do
	eval `echo $mapping | sed 's|^\([^,]*\),\(.*\)|group=\1 roles="\2"|'`
	jsroles=`echo "$roles" | sed 's|,|","|g'`
	if ! grep "^[0-9]* $mapping" $NEXUS_DATA/ldap.configured \
		>/dev/null 2>&1; then
	    if (
		    echo '{"version":"","source":"LDAP",'
		    echo "\"id\":\"$group\",\"name\":\"ldap-$group-mapping\","
		    echo "\"description\":\"LDAP $group\",\"privileges\":[],"
		    echo "\"roles\":[\"$jsroles\"]}"
		) | curl --header 'Content-Type: application/json' \
		    --header 'Accept: application/json' -X POST \
		    -u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		    $nexus_host/service/rest/beta/security/roles -d@- \
		  | grep ^200 >/dev/null; then
		echo successfully mapped LDAP group $group privileges
		echo "$(date +%s) $mapping" >>$NEXUS_DATA/ldap.configured
	    else
		echo failed provisionning LDAP group $group privileges
	    fi
	fi
    done
fi
if ! grep '^custom-deployer ' $NEXUS_DATA/roles.provisionned \
	>/dev/null 2>&1; then
    if (
	    echo '{"version":"","source":"default","id":"custom-deployer",'
	    echo '"name":"custom-deployer","description":"Deployment Role",'
	    echo '"privileges":["nx-repository-view-*-*-*","nx-search-read",'
	    echo '"nx-apikey-all"],"roles":[]}'
	) | curl --header 'Content-Type: application/json' \
	    --header 'Accept: application/json' -X POST -u "admin:$password" \
	    -s -o /dev/null -w '%{http_code}' \
	    $nexus_host/service/rest/beta/security/roles -d@- \
	  | grep ^200 >/dev/null; then
	echo successfully installed deployer role
	echo "deployer $(date +%s)" >>$NEXUS_DATA/roles.provisionned
    else
	echo failed provisionning deployer role
    fi
fi
if test "$NEXUS_JENKINS_ARTIFACTS_ACCOUNT" \
	-a "$NEXUS_ARTIFACTS_SERVICE_PASSWORD"; then
    if ! grep $NEXUS_JENKINS_ARTIFACTS_ACCOUNT \
	    $NEXUS_DATA/accounts.provisionned >/dev/null 2>&1; then
	echo " -- Creating Jenkins ARTIFACTS service user..."
	if (
		echo "{\"userId\":\"$NEXUS_JENKINS_ARTIFACTS_ACCOUNT\","
		echo '"status":"active","lastName":"Jenkins Service Account",'
		echo '"firstName":"Artifacts","emailAddress":'
		echo '"artifacts@example.com","roles":["nx-admin"],'
		echo "\"password\":\"$NEXUS_ARTIFACTS_SERVICE_PASSWORD\","
		echo '"privileges":["nx-component-upload"]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST \
		-u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/users -d@- \
	      | grep ^200 >/dev/null; then
	    echo successfully created user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT
	    echo $NEXUS_JENKINS_ARTIFACTS_ACCOUNT >>$NEXUS_DATA/accounts.provisionned
	else
	    echo failed provisionning user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT
	fi
    else
	echo user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT already povisionned
    fi
fi
if test "$NEXUS_JENKINS_DEPLOYER_ACCOUNT" -a "$NEXUS_DEPLOYER_SERVICE_PASSWORD"; then
    if ! grep $NEXUS_JENKINS_DEPLOYER_ACCOUNT \
	    $NEXUS_DATA/accounts.provisionned >/dev/null 2>&1; then
	echo " -- Creating Jenkins DEPLOYER service user ..."
	if (
		echo "{\"userId\":\"$NEXUS_JENKINS_DEPLOYER_ACCOUNT\","
		echo '"status":"active","lastName":"Jenkins Service Account",'
		echo '"firstName":"Deployer","emailAddress":'
		echo '"deployer@example.com","privileges":[],'
		echo "\"password\":\"$NEXUS_DEPLOYER_SERVICE_PASSWORD\","
		echo '"roles":["custom-deployer"]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST \
		-u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/users -d@- \
	      | grep ^200 >/dev/null; then
	    echo successfully created user $NEXUS_JENKINS_DEPLOYER_ACCOUNT
	    echo $NEXUS_JENKINS_DEPLOYER_ACCOUNT >>$NEXUS_DATA/accounts.provisionned
	else
	    echo failed provisionning user $NEXUS_JENKINS_DEPLOYER_ACCOUNT
	fi
    else
	echo user $NEXUS_JENKINS_DEPLOYER_ACCOUNT already povisionned
    fi
fi
if test "$NEXUS_ADMIN_PASSWORD"; then
    if ! test "$passwod" = "$NEXUS_ADMIN_PASSWORD"; then
	echo " -- Setting Nexus admin password..."
	if echo "$NEXUS_ADMIN_PASSWORD" | curl --header \
		"Content-Type: text/plain" --header "Accept: application/json" \
		-X PUT -u "admin:$password" -s -o /dev/null -w "%{http_code}" \
		$nexus_host/service/rest/beta/security/users/admin/change-password \
		-d@- | grep 401 >/dev/null; then
	    echo Failed changing admin password
	elif test -s $NEXUS_DATA/admin.password; then
	    echo "$NEXUS_ADMIN_PASSWORD" >$NEXUS_DATA/admin.password
	    echo successfully reset password for admin
	else
	    echo "$NEXUS_ADMIN_PASSWORD" >$NEXUS_DATA/current_local_password
	fi
    fi
fi

echo " == Provisioning Scripts Completed =="
