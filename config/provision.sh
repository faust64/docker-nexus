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

echo "* Waiting for Nexus to become available - this can take a few minutes"
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

cat <<EOF
 == Provisioning Scripts Starting ==
Executing on $nexus_host
EOF

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
	echo failed provisioning LDAP auth backend
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
		echo failed provisioning LDAP group $group privileges
	    fi
	fi
    done
fi
if test "$NEXUS_JENKINS_ARTIFACTS_ACCOUNT" -a "$NEXUS_ARTIFACTS_SERVICE_PASSWORD"; then
    if ! grep '^artifacts ' $NEXUS_DATA/roles.provisioned \
	    >/dev/null 2>&1; then
	if (
		echo '{"version":"","source":"default","id":"custom-artifacts",'
		echo '"name":"custom-artifacts","description":"Artifacts Upload Role",'
		echo '"privileges":["nx-component-upload"],"roles":[]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST -u "admin:$password" \
		-s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/roles -d@- \
	      | grep ^200 >/dev/null; then
	    echo successfully installed artifacts role
	    echo "artifacts $(date +%s)" >>$NEXUS_DATA/roles.provisioned
	else
	    echo failed provisioning artifacts role
	fi
    else
	echo role artifacts already provisioned
    fi
    if ! grep $NEXUS_JENKINS_ARTIFACTS_ACCOUNT \
	    $NEXUS_DATA/accounts.provisioned >/dev/null 2>&1; then
	echo " -- Creating Jenkins ARTIFACTS service user..."
	if (
		echo "{\"userId\":\"$NEXUS_JENKINS_ARTIFACTS_ACCOUNT\","
		echo '"status":"active","lastName":"Jenkins Service Account",'
		echo '"firstName":"Artifacts","emailAddress":'
		echo '"artifacts@example.com","roles":["custom-artifacts"],'
		echo "\"password\":\"$NEXUS_ARTIFACTS_SERVICE_PASSWORD\","
		echo '"privileges":[]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST \
		-u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/users -d@- \
	      | grep ^200 >/dev/null; then
	    echo successfully created user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT
	    echo $NEXUS_JENKINS_ARTIFACTS_ACCOUNT >>$NEXUS_DATA/accounts.provisioned
	else
	    echo failed provisioning user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT
	fi
    else
	echo user $NEXUS_JENKINS_ARTIFACTS_ACCOUNT already povisioned
    fi
fi
if test "$NEXUS_JENKINS_DEPLOYER_ACCOUNT" -a "$NEXUS_DEPLOYER_SERVICE_PASSWORD"; then
    if ! grep '^deployer ' $NEXUS_DATA/roles.provisioned \
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
	    echo "deployer $(date +%s)" >>$NEXUS_DATA/roles.provisioned
	else
	    echo failed provisioning deployer role
	fi
    else
	echo role deployer already provisioned
    fi
    if ! grep $NEXUS_JENKINS_DEPLOYER_ACCOUNT \
	    $NEXUS_DATA/accounts.provisioned >/dev/null 2>&1; then
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
	    echo $NEXUS_JENKINS_DEPLOYER_ACCOUNT >>$NEXUS_DATA/accounts.provisioned
	else
	    echo failed provisioning user $NEXUS_JENKINS_DEPLOYER_ACCOUNT
	fi
    else
	echo user $NEXUS_JENKINS_DEPLOYER_ACCOUNT already povisioned
    fi
fi
if test "$NEXUS_PROMETHEUS_ACCOUNT" -a "$NEXUS_PROMETHEUS_SERVICE_PASSWORD"; then
    if ! grep '^prometheus ' $NEXUS_DATA/roles.provisioned \
	    >/dev/null 2>&1; then
	if (
		echo '{"version":"","source":"default","id":"custom-prometheus",'
		echo '"name":"custom-prometheus","description":"Prometheus Role",'
		echo '"privileges":["nx-metrics-all","nx-atlas-all"],"roles":[]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST -u "admin:$password" \
		-s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/roles -d@- \
	      | grep ^200 >/dev/null; then
	    echo successfully installed prometheus role
	    echo "prometheus $(date +%s)" >>$NEXUS_DATA/roles.provisioned
	else
	    echo failed provisioning prometheus role
	fi
    else
	echo role prometheus already provisioned
    fi
    if ! grep $NEXUS_PROMETHEUS_ACCOUNT \
	    $NEXUS_DATA/accounts.provisioned >/dev/null 2>&1; then
	echo " -- Creating Prometheus service user ..."
	if (
		echo "{\"userId\":\"$NEXUS_PROMETHEUS_ACCOUNT\","
		echo '"status":"active","lastName":"Prometheus Service Account",'
		echo '"firstName":"Monitoring","emailAddress":'
		echo '"monitor@example.com","privileges":[],'
		echo "\"password\":\"$NEXUS_PROMETHEUS_SERVICE_PASSWORD\","
		echo '"roles":["custom-prometheus"]}'
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST \
		-u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/security/users -d@- \
	      | grep ^200 >/dev/null; then
	    echo successfully created user $NEXUS_PROMETHEUS_ACCOUNT
	    echo $NEXUS_PROMETHEUS_ACCOUNT >>$NEXUS_DATA/accounts.provisioned
	else
	    echo failed provisioning user $NEXUS_PROMETHEUS_ACCOUNT
	fi
    else
	echo user $NEXUS_PROMETHEUS_ACCOUNT already povisioned
    fi
fi
for store in $NEXUS_BLOB_STORES
do
    storedrv=file
    if echo "$store" | grep '|' >/dev/null; then
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||us-east-2|/my-prefix|encryption-key|AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||us-west-2|/my-prefix|encryption-key
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||eu-east-1|/my-prefix||AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||eu-west-2|/my-prefix
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||us-east-2||encryption-key|AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||us-west-2||encryption-key
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||eu-east-1|||AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||eu-west-2
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|||/my-prefix|encryption-key|AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|||/my-prefix|encryption-key
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|||/my-prefix||AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|||/my-prefix
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||||encryption-key|AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket||||encryption-key
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|||||AWSS3V4SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|http://radosgw:8080|us-east-1|/my-prefix||S3SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|http://radosgw:8080|us-east-1|/my-prefix
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|http://radosgw:8080|us-east-1|||S3SignerType
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|http://radosgw:8080|us-east-1
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|http://radosgw:8080||my-prefix
#my-s3-store-name|s3-access-key|s3-secret-key|my-s3-bucket|http://radosgw:8080
	s3store=$(echo "$store" | cut '-d|' -f1)
	s3user=$(echo "$store" | cut '-d|' -f2)
	s3key=$(echo "$store" | cut '-d|' -f3)
	s3bkt=$(echo "$store" | cut '-d|' -f4)
	s3gw=$(echo "$store" | cut '-d|' -f5)
	s3region=$(echo "$store" | cut '-d|' -f6)
	s3pfx=$(echo "$store" | cut '-d|' -f7)
	s3ek=$(echo "$store" | cut '-d|' -f8)
	s3st=$(echo "$store" | cut '-d|' -f9)
	if test -z "$s3key"; then
	    echo WARNING: invalid blobstore definition
	else
	    test -z "$s3bkt"    && s3bkt=$s3store
	    test -z "$s3gw"     && s3gw=https://s3.amazonaws.com
	    test -z "$s3region" && s3region=us-east-1
	    test -z "$s3pfx"    && s3pfx=
	    if test -z "$s3st"; then
		if echo "$s3gw" | grep amazonaws >/dev/null; then
		    s3st=AWSS3V4SignerType
		else
		    s3st=S3SignerType
		fi
	    fi
	    storedrv=s3
	fi
	store=$s3store
    fi
    if curl -u "admin:$password" -X GET \
	    "$nexus_host/service/rest/v1/blobstores" 2>/dev/null \
	    | grep "\"name\"[ ]*.:[ ]*\"$store\"" >/dev/null; then
	echo blobstore $store already provisioned
	continue
    elif test -e "$HOME/$store" -a "$storedrv" = file; then
	echo "WARNING: won't create blobstore $store - file exists" >&2
	continue
    fi
    if test "$storedrv" = file; then
	if (
		echo "{\"path\":\"$HOME/$store\","
		echo "\"name\":\"$store\"}"
	    ) | curl --header 'Content-Type: application/json' \
		--header 'Accept: application/json' -X POST \
		-u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		$nexus_host/service/rest/beta/blobstores/file -d@- \
	      | grep ^204 >/dev/null; then
	    echo sucessfully created blobstore $store
	else
	    echo failed provisioning blobstore $store
	fi
    elif test "$storedrv" = s3; then
	if test "$s3enckey"; then
	    if (
		    echo '{"softQuota":{"type":"string","limit":0},'
		    echo '"bucketConfiguration":{"bucket":{'
		    echo "\"region\":\"$s3region\",\"name\":"
		    echo "\"$s3bkt\",\"prefix\":\"$s3pfx\","
		    echo '"expiration": 0},"bucketSecurity":{'
		    echo "\"accessKeyId\":\"$s3user\","
		    echo "\"secretAccessKey\":\"$s3key\","
		    echo '"role":"","sessionToken":""},'
		    echo '"encryption":{"encryptionType":'
		    echo '"s3ManagedEncryption","encryptionKey":'
		    echo "\"$s3enckey\"},"
		    echo '"advancedBucketConnection":{"endpoint":'
		    echo "\"$s3gw\",\"signerType\":\"$s3st\","
		    echo '"forcePathStyle":true}},'
		    echo "\"name\":\"$store\"}"
		) | curl --header 'Content-Type: application/json' \
		    --header 'Accept: application/json' -X POST \
		    -u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		    $nexus_host/service/rest/beta/blobstores/s3 -d@- \
		  | grep ^20[14] >/dev/null; then
		echo sucessfully created s3 blobstore $store - with encryption
	    else
		echo failed provisioning s3 blobstore $store - with encryption
	    fi
	else
	    if (
		    echo '{"softQuota":{"type":"string","limit":0},'
		    echo '"bucketConfiguration":{"bucket":{'
		    echo "\"region\":\"$s3region\",\"name\":"
		    echo "\"$s3bkt\",\"prefix\":\"$s3pfx\","
		    echo '"expiration": 0},"bucketSecurity":{'
		    echo "\"accessKeyId\":\"$s3user\","
		    echo "\"secretAccessKey\":\"$s3key\","
		    echo '"role":"","sessionToken":""},'
		    echo '"advancedBucketConnection":{"endpoint":'
		    echo "\"$s3gw\",\"signerType\":\"$s3st\","
		    echo '"forcePathStyle":true}},'
		    echo "\"name\":\"$store\"}"
		) | curl --header 'Content-Type: application/json' \
		    --header 'Accept: application/json' -X POST \
		    -u "admin:$password" -s -o /dev/null -w '%{http_code}' \
		    $nexus_host/service/rest/beta/blobstores/s3 -d@- \
		  | grep ^20[14] >/dev/null; then
		echo sucessfully created s3 blobstore $store
	    else
		echo failed provisioning s3 blobstore $store
	    fi
	fi
    fi
done
for repo in $NEXUS_REPOSITORIES
do
    rname=$(echo "$repo" | cut '-d|' -f1)
    rkind=$(echo "$repo" | cut '-d|' -f2)
    rhow=$(echo "$repo" | cut '-d|' -f3)
    cstr=
    rcleanup=
    repocust=
    writepol=
    test -z "$rhow" && rhow=hosted
    test "$rhow" = hosted && writepol=",\"writePolicy\":\"allow_once\""
    test -z "$rkind" && rkind=raw

    case "$rkind" in
	apt)
	    if test "$rhow" = hosted; then
#my-apt-repo-name|apt|hosted|my-gpg-keyring-name|my-gpg-passphrase-name|my-deb-distrib-name|my-blobstore-name|my-cleanup-policy-name
#my-apt-repo-name|apt|hosted|my-gpg-keyring-name|my-gpg-passphrase-name|my-deb-distrib-name|my-blobstore-name
#my-apt-repo-name|apt|hosted|my-gpg-keyring-name|my-gpg-passphrase-name|my-deb-distrib-name
#my-apt-repo-name|apt|hosted|my-gpg-keyring-name|my-gpg-passphrase-name
		rkey=$(echo "$repo" | cut '-d|' -f4)
		if test -z "$rkey"; then
		    echo "WARNING: apt/$rname repositories requires gpg keyring" >&2
		    continue
		fi
		rpass=$(echo "$repo" | cut '-d|' -f5)
		if test -z "$rpass"; then
		    rcleanup=
		    rstore=
		    rdist=bionic
		    rpass=set-passphrase-for-$rkey
		else
		    rcleanup=$(echo "$repo" | cut '-d|' -f8)
		    rstore=$(echo "$repo" | cut '-d|' -f7)
		    rdist=$(echo "$repo" | cut '-d|' -f6)
		fi
		repocust=",\"apt\":{\"distribution\":\"$rdist\"},\"aptSigning\":{\"keypair\":\"$rkey\",\"passphrase\":\"$rpass\"}"
	    else # proxy
#my-apt-repo-name|apt|proxy|https://upstream-repo-url|my-deb-distrib-name|my-blobstore-name|my-cleanup-policy-name
#my-apt-repo-name|apt|proxy|https://upstream-repo-url|my-deb-distrib-name|my-blobstore-name
#my-apt-repo-name|apt|proxy|https://upstream-repo-url|my-deb-distrib-name
#my-apt-repo-name|apt|proxy|https://upstream-repo-url
		rremote=$(echo "$repo" | cut '-d|' -f4)
		if test -z "$rremote"; then
		    echo "WARNING: apt/$rname upstream repository required" >&2
		    continue
		fi
		rdist=$(echo "$repo" | cut '-d|' -f5)
		if test -z "$rdist"; then
		    rdist=bionic
		fi
		rcleanup=$(echo "$repo" | cut '-d|' -f7)
		rstore=$(echo "$repo" | cut '-d|' -f6)
		repocust=",\"proxy\":{\"remoteUrl\":\"$rremote\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440}"
		repocust="$repocust,\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440},\"apt\":{\"distribution\":\"$rdist\",\"flat\":false}"
		repocust="$repocust,\"httpClient\":{\"blocked\":false,\"autoBlock\":true,\"connection\":{\"retries\":0"
		repocust="$repocust,\"userAgentSuffix\":\"reposync\",\"timeout\":60,\"enableCircularRedirects\":false,\"enableCookies\":false}}"
	    fi
	    ;;
	docker)
	    if test "$rhow" = hosted; then
#my-dkr-repo-name|docker|hosted|my-repo-https-port|yes|my-blobstore-name|my-cleanup-policy-name
#my-dkr-repo-name|docker|hosted|my-repo-https-port|yes|my-blobstore-name
#my-dkr-repo-name|docker|hosted|my-repo-https-port|yes
#my-dkr-repo-name|docker|hosted|my-repo-http-port||my-blobstore-name|my-cleanup-policy-name
#my-dkr-repo-name|docker|hosted|my-repo-http-port||my-blobstore-name
#my-dkr-repo-name|docker|hosted|my-repo-http-port
#my-dkr-repo-name|docker|hosted
		rport=$(echo "$repo" | cut '-d|' -f4)
		rauth=$(echo "$repo" | cut '-d|' -f5)
		rstore=$(echo "$repo" | cut '-d|' -f6)
		rcleanup=$(echo "$repo" | cut '-d|' -f7)
		if test "$rport" -ge 1024 >/dev/null 2>&1; then
		    if test -z "$rauth"; then
			repocust=",\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":false,\"httpPort\":$rport}"
		    else
			repocust=",\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":true,\"httpsPort\":$rport}"
		    fi
		else
		    echo "WARNING: Using default Nexus listener, consider setting a dedicated port instead" >&2
		    repocust=",\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":false}"
		fi
	    else #proxy
#my-dkr-repo-name|docker|proxy|https://upstream.dkr|my-repo-https-port|yes|my-blobstore-name|my-cleanup-policy-name
#my-dkr-repo-name|docker|proxy|https://upstream.dkr|my-repo-https-port|yes|my-blobstore-name
#my-dkr-repo-name|docker|proxy|https://upstream.dkr|my-repo-https-port|yes
#my-dkr-repo-name|docker|proxy|https://upstream.dkr|my-repo-http-port||my-blobstore-name|my-cleanup-policy-name
#my-dkr-repo-name|docker|proxy|https://upstream.dkr|my-repo-http-port||my-blobstore-name
#my-dkr-repo-name|docker|proxy|https://upstream.dkr|my-repo-http-port
#my-dkr-repo-name|docker|proxy|https://upstream.dkr
		rremote=$(echo "$repo" | cut '-d|' -f4)
		if test -z "$rremote"; then
		    echo "WARNING: docker/$rname upstream repository required" >&2
		    continue
		fi
		rport=$(echo "$repo" | cut '-d|' -f5)
		rauth=$(echo "$repo" | cut '-d|' -f6)
		rstore=$(echo "$repo" | cut '-d|' -f7)
		rcleanup=$(echo "$repo" | cut '-d|' -f8)
		if test "$rport" -ge 1024 >/dev/null 2>&1; then
		    if test -z "$rauth"; then
			repocust=",\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":false,\"httpPort\":$rport}"
		    else
			repocust=",\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":true,\"httpsPort\":$rport}"
		    fi
		else
		    echo "WARNING: Using default Nexus listener, consider setting a dedicated port instead" >&2
		    repocust=",\"docker\":{\"v1Enabled\":false,\"forceBasicAuth\":false}"
		fi
		repocust="$repocust,\"proxy\":{\"remoteUrl\":\"$rremote\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440}"
		repocust="$repocust,\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440}"
		repocust="$repocust,\"httpClient\":{\"blocked\":false,\"autoBlock\":true,\"connection\":{\"retries\":0"
		repocust="$repocust,\"userAgentSuffix\":\"reposync\",\"timeout\":60,\"enableCircularRedirects\":false,\"enableCookies\":false}}"
		repocust="$repocust,\"dockerProxy\":{\"indexType\":\"HUB\"}"
	    fi
	    ;;
	npm)
	    if test "$rhow" = hosted; then
#my-npm-repo-name|npm|hosted|my-blobstore-name|my-cleanup-policy-name
#my-npm-repo-name|npm|hosted|my-blobstore-name
#my-npm-repo-name|npm|hosted
		rstore=$(echo "$repo" | cut '-d|' -f4)
		rcleanup=$(echo "$repo" | cut '-d|' -f5)
	    else # proxy
#my-npm-repo-name|npm|proxy|https://registry.npm|my-blobstore-name|my-cleanup-policy-name
#my-npm-repo-name|npm|proxy|https://registry.npm|my-blobstore-name
#my-npm-repo-name|npm|proxy|https://registry.npm
		rremote=$(echo "$repo" | cut '-d|' -f4)
		rstore=$(echo "$repo" | cut '-d|' -f5)
		rcleanup=$(echo "$repo" | cut '-d|' -f6)
		repocust=",\"proxy\":{\"remoteUrl\":\"$rremote\",\"contentMaxAge\":1440,\"metadataMaxAge\":1440}"
		repocust="$repocust,\"negativeCache\":{\"enabled\":true,\"timeToLive\":1440}"
		repocust="$repocust,\"httpClient\":{\"blocked\":false,\"autoBlock\":true,\"connection\":{\"retries\":0"
		repocust="$repocust,\"userAgentSuffix\":\"reposync\",\"timeout\":60,\"enableCircularRedirects\":false,\"enableCookies\":false}}"
	    fi
	    ;;
	*)
#my-raw-repo-name|raw|hosted|my-blobstore-name|my-cleanup-policy-name
#my-raw-repo-name|raw|hosted|my-blobstore-name
#my-raw-repo-name|raw|hosted
#my-raw-repo-name|raw
#my-raw-repo-name|<invalid-kind>|<ignored-rhow>|my-blobstore-name|my-cleanup-policy-name
#my-raw-repo-name|<invalid-kind>|<ignored-rhow>|my-blobstore-name
#my-raw-repo-name|<invalid-kind>|<ignored-rhow>
#my-raw-repo-name|<invalid-kind>
#my-raw-repo-name
	    if ! test "$rkind" = raw; then
		echo "WARNING: repo type $rkind support not implemented" >&2
		echo "         see $nexus_host/#admin/system/api" >&2
		echo "         creating raw hosted repo" >&2
	    fi
	    rcleanup=$(echo "$repo" | cut '-d|' -f5)
	    rstore=$(echo "$repo" | cut '-d|' -f4)
	    repocust=",\"raw\":{\"contentDisposition\":\"ATTACHMENT\"}"
	    ;;
    esac
    if test -z "$rstore"; then
	rstore=default
    elif ! test -d "$HOME/$rstore"; then
	echo "WARNING: store=$rstore does not exist, fallback to default" >&2
	rstore=default
    fi
    if test "$rcleanup"; then
	cstr=",\"cleanup\":{\"policyNames\":[\"$rcleanup\"]}"
    fi
    if curl -u "admin:$password" -X GET \
	    "$nexus_host/service/rest/v1/repositories" 2>/dev/null \
	    | grep "\"name\"[ ]*.:[ ]*\"$rname\"" >/dev/null; then
	echo repository $rname already provisioned
    elif (
	    echo "{\"name\":\"$rname\",\"online\":true,\"storage\":"
	    echo "{\"blobStoreName\":\"$rstore\","
	    echo "\"strictContentTypeValidation\":true$writepol"
	    echo "}$cstr$repocust}"
	) | curl --header 'Content-Type: application/json' \
	    --header 'Accept: application/json' -X POST \
	    -u "admin:$password" -s -o /dev/null -w '%{http_code}' \
	    "$nexus_host/service/rest/v1/repositories/$rkind/$rhow" -d@- \
	      | grep ^201 >/dev/null; then
	echo "successfully created repository name=$rname kind=$rkind/$rhow store=$rstore"
    else
	echo "failed provisioning repository name=$rname kind=$rkind/$rhow store=$rstore"
    fi
done
if test "$NEXUS_ADMIN_PASSWORD"; then
    if ! test "$password" = "$NEXUS_ADMIN_PASSWORD"; then
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
