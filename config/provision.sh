#!/bin/sh

if test "$DEBUG"; then
    set -x
fi

if test -s $NEXUS_DATA/current_local_password; then
    password=$(head -1 $NEXUS_DATA/current_local_password | tr -d '\n')
else
    echo "[ERR] File $NEXUS_DATA/current_local_password doesn't exist."
    echo "This file should include your current local password."
    exit 1
fi >&2

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

function addAndRunScript()
{
    name=$1
    file=$2
    eval args="${3:-false}"
    classPath=$(find /root/.groovy/grapes -name *.jar)
    groovy -cp $(echo $classPath | sed 's/ /:/g') \
	-Dgroovy.grape.report.downloads=true \
	resources/conf/addUpdatescript.groovy -f "$file" \
	-u "$username" -p "$password" -n "$name" -h "$nexus_host"
    echo "  -- Published $file as $name"
    curl -v -X POST -u "$username:$password" \
	--header "Content-Type: text/plain" -d "$args" \
	"$nexus_host/service/rest/v1/script/$name/run"
    echo "  -- Successfully executed $name script"
}

cat <<EOF
 == Provisioning Integration API Scripts Starting ==

Publishing and executing on $nexus_host
EOF

if test "$NEXUS_BASE_URL"; then
    echo " -- Setting Base URL: $NEXUS_BASE_URL"
    baseUrlArg="{\"base_url\":\"$NEXUS_BASE_URL\"}"
    addAndRunScript baseUrl resources/conf/setup_base_url.groovy "\$baseUrlArg"
fi
if test "$USER_AGENT"; then
    echo " -- Setting User Agent: $USER_AGENT"
    userAgentArg="{\"user_agent\":\"$USER_AGENT\"}"
    addAndRunScript userAgent resources/conf/setup_user_agent.groovy "\$userAgentArg"
fi
if test "$NEXUS_PROXY_HOST"; then
    NEXUS_PROXY_PORT=${NEXUS_PROXY_HOST:-3128}
    echo " -- Setting Proxy Host: $NEXUS_PROXY_HOST:$NEXUS_PROXY_PORT"
    remoteProxyArg="{\"with_http_proxy\":\"true\",\"http_proxy_host\":\"$NEXUS_PROXY_HOST\",\"http_proxy_port\":\"$NEXUS_PROXY_PORT\"}"
    addAndRunScript remoteProxy resources/conf/setup_http_proxy.groovy "\$remoteProxyArg"
fi
if test "$LDAP_ENABLED" = true; then
    LDAP_NAME=${LDAP_NAME:-'LDAP-Auth'}
    test -z "$LDAP_URI" && LDAP_URI="ldap://localhost/"
    LDAP_PROTO=`echo "$LDAP_URI" | cut -d: -f1`
    test "$LDAP_PROTO" = ldap -o "$LDAP_PROTO" = ldaps || LDAP_PROTO=ldap
    LDAP_HOST=`echo "$LDAP_URI" | sed 's|^\([ldaps]*://\)\{0,1\}\([^/]*\)[/]*.*|\2|'`
    if echo "$LDAP_HOST" | grep : >/dev/null; then
	LDAP_PORT=`echo "$LDAP_HOST" | cut -d: -f2`
	LDAP_HOST=`echo "$LDAP_HOST" | cut -d: -f1`
    elif test "$LDAP_PROTO" = ldaps; then
	LDAP_PORT=636
    else
	LDAP_PORT=389
    fi
    LDAP_USERS=${LDAP_USERS:-'ou=users'}
    LDAP_GROUPS=${LDAP_GROUPS:-'ou=groups'}
    LDAP_GROUPS_AS_ROLES=${LDAP_GROUPS_AS_ROLES:-'true'}
    LDAP_BASE=${LDAP_BASE:-'dc=demo,dc=local'}
    LDAP_MAP_GROUP_AS_ROLES=${LDAP_MAP_GROUP_AS_ROLES:-'true'}
    LDAP_AUTH_SCHEME=${LDAP_AUTH_SCHEME:-'simple'}
    LDAP_BIND_PASSWORD=${LDAP_BIND_PASSWORD:-'secret'}
    LDAP_BIND_DN=${LDAP_BIND_DN:-'cn=admin,dc=demo,dc=local'}
    LDAP_USER_EMAIL_ATTRIBUTE=${LDAP_USER_EMAIL_ATTRIBUTE:-'mail'}
    LDAP_GROUP_ID_ATTRIBUTE=${LDAP_GROUP_ID_ATTRIBUTE:-'cn'}
    LDAP_GROUP_MEMBER_ATTRIBUTE=${LDAP_GROUP_MEMBER_ATTRIBUTE:-'member'}
    LDAP_GROUP_OBJECT_CLASS=${LDAP_GROUP_OBJECT_CLASS:-'groupOfNames'}
    LDAP_PREFERRED_PASSWORD_ENCODING=${LDAP_PREFERRED_PASSWORD_ENCODING:-'crypt'}
    LDAP_USER_ID_ATTRIBUTE=${LDAP_USER_ID_ATTRIBUTE:-'uid'}
    LDAP_USER_PASSWORD_ATTRIBUTE=${LDAP_USER_PASSWORD_ATTRIBUTE:-'userPassword'}
    LDAP_USER_OBJECT_CLASS=${LDAP_USER_OBJECT_CLASS:-'inetOrgPerson'}
    LDAP_USER_REAL_NAME_ATTRIBUTE=${LDAP_USER_REAL_NAME_ATTRIBUTE:-'cn'}
    LDAP_GROUP_MEMBER_FORMAT='${dn}'
    LDAP_USER_GROUP_CONFIG="{\"name\":\"$LDAP_NAME\",\"map_groups_as_roles\":\"$LDAP_MAP_GROUP_AS_ROLES\",\"protocol\":\"$LDAP_PROTO\",\"host\":\"$LDAP_HOST\",\"port\":\"$LDAP_PORT\",\"searchBase\":\"$LDAP_BASE\",\"auth\":\"$LDAP_AUTH_SCHEME\",\"systemPassword\":\"$LDAP_BIND_PASSWORD\",\"systemUsername\":\"$LDAP_BIND_DN\",\"emailAddressAttribute\":\"$LDAP_USER_EMAIL_ATTRIBUTE\",\"ldapGroupsAsRoles\":\"$LDAP_GROUPS_AS_ROLES\",\"groupBaseDn\":\"$LDAP_GROUPS\",\"groupIdAttribute\":\"$LDAP_GROUP_ID_ATTRIBUTE\",\"groupMemberAttribute\":\"$LDAP_GROUP_MEMBER_ATTRIBUTE\",\"groupMemberFormat\":\"$LDAP_GROUP_MEMBER_FORMAT\",\"groupObjectClass\":\"$LDAP_GROUP_OBJECT_CLASS\",\"userIdAttribute\":\"$LDAP_USER_ID_ATTRIBUTE\",\"userPasswordAttribute\":\"$LDAP_USER_PASSWORD_ATTRIBUTE\",\"userObjectClass\":\"$LDAP_USER_OBJECT_CLASS\",\"userBaseDn\":\"$LDAP_USERS\",\"userRealNameAttribute\":\"$LDAP_USER_REAL_NAME_ATTRIBUTE\"}"
    addAndRunScript ldapConfig resources/conf/ldapconfig.groovy "\$LDAP_USER_GROUP_CONFIG"
    if test "$NEXUS_CUSTOM_DEPLOY_ROLE$NEXUS_CUSTOM_DEV_ROLE"; then
	echo " -- Creating LDAP roles and mappings..."
	if test "$NEXUS_CUSTOM_DEPLOY_ROLE"; then
	    NEXUS_DEPLOY_ROLE_CONFIG="{\"id\":\"$NEXUS_CUSTOM_DEPLOY_ROLE\",\"name\":\"$NEXUS_CUSTOM_DEPLOY_ROLE\",\"description\":\"Deployment_Role\",\"privileges\":"[]",\"roles\":"[\"nx-admin\"]"}"
	    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_DEPLOY_ROLE_CONFIG"
	fi
	if test -n "$NEXUS_CUSTOM_DEV_ROLE"; then
	    NEXUS_DEVELOP_ROLE_CONFIG="{\"id\":\"$NEXUS_CUSTOM_DEV_ROLE\",\"name\":\"$NEXUS_CUSTOM_DEV_ROLE\",\"description\":\"Developer_Role\",\"privileges\":"[]",\"roles\":"[\"nx-anonymous\"]"}"
	    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_DEVELOP_ROLE_CONFIG"
	fi
    fi
fi
if test -n "$NEXUS_CUSTOM_ADMIN_ROLE"; then
    echo " -- Creating Custom ADMIN role and mapping..."
    NEXUS_ADMIN_ROLE_CONFIG="{\"id\":\"$NEXUS_CUSTOM_ADMIN_ROLE\",\"name\":\"$NEXUS_CUSTOM_ADMIN_ROLE\",\"description\":\"Adminstration_Role\",\"privileges\":"[\"nx-all\"]",\"roles\":"[\"nx-admin\"]"}"
    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_ADMIN_ROLE_CONFIG"
fi
if test "$NEXUS_JENKINS_ARTIFACTS_ACCOUNT" -a "$NEXUS_ARTIFACTS_SERVICE_PASSWORD"; then
    echo " -- Creating Jenkins ARTIFACTS service user and role..."
    NEXUS_ARTIFACTS_ROLE_CONFIG="{\"id\":\"jenkins-artifacts\",\"name\":\"jenkins-artifacts\",\"description\":\"Jenkins Artifacts Upload\",\"privileges\":"[\"nx-component-upload\"]",\"roles\":"[\"nx-admin\"]"}"
    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_ARTIFACTS_ROLE_CONFIG"
    NEXUS_ARTIFACTS_USER_CONFIG="{\"username\":\"$NEXUS_JENKINS_ARTIFACTS_ACCOUNT\",\"firstname\":\"Jenkins Artifacts\",\"lastname\":\"Service Account\",\"email\":\"artifacts@example.com\",\"password\":\"$NEXUS_ARTIFACTS_SERVICE_PASSWORD\",\"role\":\"jenkins-artifacts\"}"
    addAndRunScript insertUser resources/conf/insertuser.groovy "\$NEXUS_ARTIFACTS_USER_CONFIG"
fi
if test "$NEXUS_JENKINS_DEPLOYER_ACCOUNT" -a "$NEXUS_DEPLOYER_SERVICE_PASSWORD"; then
    echo " -- Creating Jenkins DEPLOYER service user and role..."
    NEXUS_DEPLOYER_ROLE_CONFIG="{\"id\":\"jenkins-deployer\",\"name\":\"jenkins-deployer\",\"description\":\"Jenkins Deployer\",\"privileges\":"[\"nx-search-read\",\"nx-repository-view-*-*-read\",\"nx-repository-view-*-*-browse\",\"nx-repository-view-*-*-add\",\"nx-repository-view-*-*-edit\",\"nx-apikey-all\"]",\"roles\":"[\"nx-admin\"]"}"
    addAndRunScript insertRole resources/conf/insertrole.groovy "\$NEXUS_DEPLOYER_ROLE_CONFIG"
    NEXUS_DEPLOYER_USER_CONFIG="{\"username\":\"$NEXUS_JENKINS_DEPLOYER_ACCOUNT\",\"firstname\":\"Jenkins Deployer\",\"lastname\":\"Service Account\",\"email\":\"deploy@example.com\",\"password\":\"$NEXUS_DEPLOYER_SERVICE_PASSWORD\",\"role\":\"jenkins-deployer\"}"
    addAndRunScript insertUser resources/conf/insertuser.groovy "\$NEXUS_DEPLOYER_USER_CONFIG"
fi
if test -n "$NEXUS_ADMIN_PASSWORD"; then
    echo " -- Setting Nexus default admin password..."
    NEXUS_PASSWORD="{\"new_password\":\"$NEXUS_ADMIN_PASSWORD\"}"
    addAndRunScript updatePassword resources/conf/update_admin_password.groovy "\$NEXUS_PASSWORD"
    echo "$NEXUS_ADMIN_PASSWORD" >$NEXUS_DATA/current_local_password
fi

echo " == Provisioning Scripts Completed =="
