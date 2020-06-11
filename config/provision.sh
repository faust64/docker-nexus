#!/bin/bash

if test "$DEBUG"; then
    set -x
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

#if test "$NEXUS_BASE_URL"; then
#    echo " -- Setting Base URL: $NEXUS_BASE_URL"
#    baseUrlArg=$(jq -n -c --arg value "$NEXUS_BASE_URL" '{base_url: $value}')
#    addAndRunScript baseUrl resources/conf/setup_base_url.groovy "\$baseUrlArg"
#fi
#if test "$USER_AGENT"; then
#    echo " -- Setting User Agent: $USER_AGENT"
#    userAgentArg=$(jq -n -c --arg value "$USER_AGENT" '{user_agent: $value}')
#    addAndRunScript userAgent resources/conf/setup_user_agent.groovy "\$userAgentArg"
#fi
#if test "$NEXUS_PROXY_HOST"; then
#    NEXUS_PROXY_PORT=${NEXUS_PROXY_HOST:-3128}
#    echo " -- Setting Proxy Host: $NEXUS_PROXY_HOST:$NEXUS_PROXY_PORT"
#    remoteProxyArg=$(jq -n -c --arg host "$NEXUS_PROXY_HOST" --arg port "$NEXUS_PROXY_PORT" '{with_http_proxy: "true", http_proxy_host: $host, http_proxy_port: $port}')
#    addAndRunScript remoteProxy resources/conf/setup_http_proxy.groovy "\$remoteProxyArg"
#fi
#if test "$LDAP_ENABLED" = true; then
#    LDAP_NAME=${LDAP_NAME:-'LDAP-Auth'}
#    test -z "$LDAP_URI" && LDAP_URI="ldap://localhost/"
#    LDAP_PROTO=`echo "$LDAP_URI" | cut -d: -f1`
#    test "$LDAP_PROTO" = ldap -o "$LDAP_PROTO" = ldaps || LDAP_PROTO=ldap
#    LDAP_HOST=`echo "$LDAP_URI" | sed 's|^\([ldaps]*://\)\{0,1\}\([^/]*\)[/]*.*|\2|'`
#    if echo "$LDAP_HOST" | grep : >/dev/null; then
#	LDAP_PORT=`echo "$LDAP_HOST" | cut -d: -f2`
#	LDAP_HOST=`echo "$LDAP_HOST" | cut -d: -f1`
#    elif test "$LDAP_PROTO" = ldaps; then
#	LDAP_PORT=636
#    else
#	LDAP_PORT=389
#    fi
#    LDAP_USERS=${LDAP_USERS:-'ou=users'}
#    LDAP_GROUPS=${LDAP_GROUPS:-'ou=groups'}
#    LDAP_GROUPS_AS_ROLES=${LDAP_GROUPS_AS_ROLES:-'true'}
#    LDAP_BASE=${LDAP_BASE:-'dc=demo,dc=local'}
#    LDAP_MAP_GROUP_AS_ROLES=${LDAP_MAP_GROUP_AS_ROLES:-'true'}
#    LDAP_AUTH_SCHEME=${LDAP_AUTH_SCHEME:-'simple'}
#    LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-'secret'}
#    LDAP_BIND_DN=${LDAP_BIND_DN:-'cn=admin,dc=demo,dc=local'}
#    LDAP_USER_EMAIL_ATTRIBUTE=${LDAP_USER_EMAIL_ATTRIBUTE:-'mail'}
#    LDAP_GROUP_ID_ATTRIBUTE=${LDAP_GROUP_ID_ATTRIBUTE:-'cn'}
#    LDAP_GROUP_MEMBER_ATTRIBUTE=${LDAP_GROUP_MEMBER_ATTRIBUTE:-'member'}
#    LDAP_GROUP_OBJECT_CLASS=${LDAP_GROUP_OBJECT_CLASS:-'groupOfNames'}
#    LDAP_PREFERRED_PASSWORD_ENCODING=${LDAP_PREFERRED_PASSWORD_ENCODING:-'crypt'}
#    LDAP_USER_ID_ATTRIBUTE=${LDAP_USER_ID_ATTRIBUTE:-'uid'}
#    LDAP_USER_PASSWORD_ATTRIBUTE=${LDAP_USER_PASSWORD_ATTRIBUTE:-'userPassword'}
#    LDAP_USER_OBJECT_CLASS=${LDAP_USER_OBJECT_CLASS:-'inetOrgPerson'}
#    LDAP_USER_REAL_NAME_ATTRIBUTE=${LDAP_USER_REAL_NAME_ATTRIBUTE:-'cn'}
#    LDAP_GROUP_MEMBER_FORMAT='${dn}'
#
#    LDAP_USER_GROUP_CONFIG=$(jq -n -c \
#	    --arg name "$LDAP_NAME" \
#	    --arg map_groups_as_roles "$LDAP_MAP_GROUP_AS_ROLES" \
#	    --arg protocol "$LDAP_PROTO" \
#	    --arg host "$LDAP_HOST" \
#	    --arg port "$LDAP_PORT" \
#	    --arg searchBase "$LDAP_BASE" \
#	    --arg auth "$LDAP_AUTH_SCHEME" \
#	    --arg systemPassword "$LDAP_BIND_PASSWORD" \
#	    --arg systemUsername "$LDAP_BIND_DN" \
#	    --arg emailAddressAttribute "$LDAP_USER_EMAIL_ATTRIBUTE" \
#	    --arg ldapGroupsAsRoles "$LDAP_GROUPS_AS_ROLES" \
#	    --arg groupBaseDn "$LDAP_GROUPS" \
#	    --arg groupIdAttribute "$LDAP_GROUP_ID_ATTRIBUTE" \
#	    --arg groupMemberAttribute "$LDAP_GROUP_MEMBER_ATTRIBUTE" \
#	    --arg groupMemberFormat "$LDAP_GROUP_MEMBER_FORMAT" \
#	    --arg groupObjectClass "$LDAP_GROUP_OBJECT_CLASS" \
#	    --arg userIdAttribute "$LDAP_USER_ID_ATTRIBUTE" \
#	    --arg userPasswordAttribute "$LDAP_USER_PASSWORD_ATTRIBUTE" \
#	    --arg userObjectClass "$LDAP_USER_OBJECT_CLASS" \
#	    --arg userBaseDn "$LDAP_USERS" \
#	    --arg userRealNameAttribute "$LDAP_USER_REAL_NAME_ATTRIBUTE" \
#	    '{name: $name, map_groups_as_roles: $map_groups_as_roles, protocol: $protocol, host: $host, port: $port, searchBase: $searchBase, auth: $auth, systemPassword: $systemPassword, systemUsername: $systemUsername, emailAddressAttribute: $emailAddressAttribute, ldapGroupsAsRoles: $ldapGroupsAsRoles, groupBaseDn: $groupBaseDn, groupIdAttribute: $groupIdAttribute, groupMemberAttribute: $groupMemberAttribute, groupMemberFormat: $groupMemberFormat, groupObjectClass: $groupObjectClass, userIdAttribute: $userIdAttribute, userPasswordAttribute: $userPasswordAttribute, userObjectClass: $userObjectClass, userBaseDn: $userBaseDn, userRealNameAttribute: $userRealNameAttribute}'
#	)
#    addAndRunScript ldapConfig resources/conf/ldapconfig.groovy "\$LDAP_USER_GROUP_CONFIG"
#    if test "$NEXUS_CUSTOM_DEPLOY_ROLE$NEXUS_CUSTOM_DEV_ROLE"; then
#	echo " -- Creating LDAP roles and mappings..."
#	if test "$NEXUS_CUSTOM_DEPLOY_ROLE"; then
#	    NEXUS_DEPLOY_ROLE_CONFIG=$(jq -n -c \
#		    --arg id "$NEXUS_CUSTOM_DEPLOY_ROLE" \
#		    --arg name "$NEXUS_CUSTOM_DEPLOY_ROLE" \
#		    '{id: $id, name: $name, description: "Deployment_Role", privileges: ["nx-ldap-all", "nx-roles-all"], roles: ["nx-admin"]}'
#		)
#	    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_DEPLOY_ROLE_CONFIG"
#	fi
#	if test -n "$NEXUS_CUSTOM_DEV_ROLE"; then
#	    NEXUS_DEVELOP_ROLE_CONFIG=$(jq -n -c \
#		    --arg id "$NEXUS_CUSTOM_DEVELOP_ROLE" \
#		    --arg name "$NEXUS_CUSTOM_DEVELOP_ROLE" \
#		    '{id: $id, name: $name, description: "Developer_Role", privileges: ["nx-roles-update", "nx-ldap-update"], roles: ["nx-admin", "nx-anonymous"]}'
#		)
#	    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_DEVELOP_ROLE_CONFIG"
#	fi
#    fi
#fi
#if test -n "$NEXUS_CUSTOM_ADMIN_ROLE"; then
#    echo " -- Creating Custom ADMIN role and mapping..."
#    NEXUS_ADMIN_ROLE_CONFIG=$(jq -n -c \
#	    --arg id "$NEXUS_CUSTOM_ADMIN_ROLE" \
#	    --arg name "$NEXUS_CUSTOM_ADMIN_ROLE" \
#	    '{id: $id, name: $name, description: "Administration_Role", privileges: ["nx-all"], roles: ["nx-admin"]}'
#	)
#    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_ADMIN_ROLE_CONFIG"
#fi
if test "$NEXUS_JENKINS_ARTIFACTS_ACCOUNT" -a "$NEXUS_ARTIFACTS_SERVICE_PASSWORD"; then
    if ! grep $NEXUS_JENKINS_ARTIFACTS_ACCOUNT \
	    $NEXUS_DATA/accounts.provisionned >/dev/null 2>&1; then
	echo " -- Creating Jenkins ARTIFACTS service user..."
	if (
		echo "{\"userId\":\"$NEXUS_JENKINS_ARTIFACTS_ACCOUNT\","
		echo '"status":"active","lastName":"Jenkins Service Account",'
		echo '"firstName":"Artifacts","emailAddress":"artifacts@example.com",'
		echo "\"password\":\"$NEXUS_ARTIFACTS_SERVICE_PASSWORD\","
		echo '"privileges":["nx-component-upload"],"roles":["nx-admin"]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST -u "admin:$password" \
		-s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/users -d@- | grep ^200 >/dev/null; then
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
		echo '"firstName":"Deployer","emailAddress":"deployer@example.com",'
		echo "\"password\":\"$NEXUS_DEPLOYER_SERVICE_PASSWORD\","
		echo '"privileges":["nx-search-read","nx-repository-view-*-*-read",'
		echo '"nx-repository-view-*-*-browse","nx-repository-view-*-*-add",'
		echo '"nx-repository-view-*-*-edit","nx-apikey-all"],'
		echo '"roles":["nx-admin"]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST -u "admin:$password" \
		-s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/users -d@- | grep ^200 >/dev/null; then
	    echo successfully created user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT
	    echo $NEXUS_JENKINS_ARTIFACTS_ACCOUNT >$NEXUS_DATA/accounts.provisionned
	else
	    echo failed provisionning user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT
	fi
    else
	echo user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT already povisionned
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
