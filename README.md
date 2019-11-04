# Nexus

OpenShift-friendly

Based on https://github.com/Accenture/adop-nexus

Build with:
```
$ make build
```

If you want to try it quickly on your local machine after make, run :
```
$ make run
```

You should be able to access it on `localhost:8081`

FIXME/TODO: ldap auth could require adding proper CA chain into Nexus trust
store, then enabling the "use certificates stored in nexuse" option in LDAP Auth
source settings.

Environment variables and volumes
----------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker `run` command.

|    Variable name                    |    Description                   | Default                     |
| :---------------------------------- | -------------------------------- | --------------------------- |
|  `LDAP_BASE`                        | LDAP Search Base                 | `dc=demo,dc=local`          |
|  `LDAP_USERS`                       | LDAP Users Prefix                | `ou=users`                  |
|  `LDAP_GROUPS`                      | LDAP Groups Prefix               | `ou=groups`                 |
|  `LDAP_GROUPS_AS_ROLES`             | LDAP Groups as Nexus Roles       | `true`                      |
|  `LDAP_MAP_GROUP_AS_ROLES`          | LDAP Map Groups as Nexus Roles   | `true`                      |
|  `LDAP_AUTH_SCHEME`                 | LDAP Auth scheme                 | `simple`                    |
|  `LDAP_BIND_DN`                     | LDAP Service Account Bind DN     | `cn=admin,dc=demo,dc=local` |
|  `LDAP_BIND_PASSWORD`               | LDAP Service Account Bind PW     | `secret`                    |
|  `LDAP_GROUP_ID_ATTRIBUTE`          | LDAP Group ID Attribute          | `cn`                        |
|  `LDAP_GROUP_MEMBER_ATTRIBUTE`      | LDAP Group Member Attribute      | `member`                    |
|  `LDAP_GROUP_MEMBER_FORMAT`         | LDAP Group Member Format         | `${dn}`                     |
|  `LDAP_GROUP_OBJECT_CLASS`          | LDAP Groups Object Class         | `groupOfNames`              |
|  `LDAP_NAME`                        | LDAP Source Name                 | `LDAP-Auth`                 |
|  `LDAP_PREFERRED_PASSWORD_ENCODING` | LDAP Preferred Password Encoding | `crypt`                     |
|  `LDAP_USER_EMAIL_ATTRIBUTE`        | LDAP User Email Attribute        | `mail`                      |
|  `LDAP_USER_ID_ATTRIBUTE`           | LDAP User ID Attribute           | `uid`                       |
|  `LDAP_USER_OBJECT_CLASS`           | LDAP User Object Class           | `inetOrgPerson`             |
|  `LDAP_USER_PASSWORD_ATTRIBUTE`     | LDAP User Password Attribute     | `userPassword`              |
|  `LDAP_USER_REAL_NAME_ATTRIBUTE`    | LDAP User Real Name Attribute    | `cn`                        |
|  `LDAP_URI`                         | LDAP Host URI                    | `ldap://localhost:389`      |
|  `NEXUS_ADMIN_PASSWORD`             | Nexus Admin Password             | `admin123`                  |
|  `NEXUS_ARTIFACTS_SERVICE_PASSWORD` | Nexus Jenkins-Artifacts Password | `undef`                     |
|  `NEXUS_DEPLOYER_SERVICE_PASSWORD`  | Nexus Jenkins-Deployer Password  | `undef`                     |
|  `NEXUS_CUSTOM_ADMIN_ROLE`          | Nexus Custom Admin Role          | `undef`                     |
|  `NEXUS_CUSTOM_DEPLOY_ROLE`         | Nexus LDAP-backed Deploy Role    | `undef`                     |
|  `NEXUS_CUSTOM_DEV_ROLE`            | Nexus LDAP-backed Dev Role       | `undef`                     |
|  `NEXUS_JENKINS_ARTIFACTS_ACCOUNT`  | Nexus Jenkins-Artifacts Account  | `undef`                     |
|  `NEXUS_JENKINS_DEPLOYER_ACCOUNT`   | Nexus Jenkins-Deployer Account   | `undef`                     |
|  `NEXUS_PROXY_HOST`                 | Proxy HTTP Host                  | `undef`                     |
|  `NEXUS_PROXY_PORT`                 | Proxy HTTP Port                  | `3128`                      |

You can also set the following mount points by passing the `-v /host:/container` flag to Docker.

|  Volume mount point    | Description              |
| :--------------------- | ------------------------ |
|  `/nexus`              | Nexus Persisting Data    |
|  `/certs`              | Nexus CAs to load        |
