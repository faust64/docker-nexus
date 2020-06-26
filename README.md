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

Note scripts were removed from provisioning, as it relies on some functionnality
that is now disabled. See
https://help.sonatype.com/repomanager3/rest-and-integration-api/script-api

Admin password initialization and additional service accounts provisioning have
been fixed accordingly. The rest remains in my todolist.

Environment variables and volumes
----------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker `run` command.

|    Variable name                    |    Description                   | Default                                                     |
| :---------------------------------- | -------------------------------- | ----------------------------------------------------------- |
|  `NEXUS_ADMIN_PASSWORD`             | Nexus Admin Password             | `admin123`                                                  |
|  `NEXUS_ARTIFACTS_SERVICE_PASSWORD` | Nexus Jenkins-Artifacts Password | undef                                                       |
|  `NEXUS_DEPLOYER_SERVICE_PASSWORD`  | Nexus Jenkins-Deployer Password  | undef                                                       |
|  `NEXUS_JENKINS_ARTIFACTS_ACCOUNT`  | Nexus Jenkins-Artifacts Account  | undef                                                       |
|  `NEXUS_JENKINS_DEPLOYER_ACCOUNT`   | Nexus Jenkins-Deployer Account   | undef                                                       |
|  `OPENLDAP_BASE`                    | OpenLDAP Base                    | seds `OPENLDAP_DOMAIN`, default produces `dc=demo,dc=local` |
|  `OPENLDAP_BIND_DN_RREFIX`          | OpenLDAP Bind DN Prefix          | `cn=whitepages,ou=services`                                 |
|  `OPENLDAP_BIND_PW`                 | OpenLDAP Bind Password           | `secret`                                                    |
|  `OPENLDAP_DOMAIN`                  | OpenLDAP Domain Name             | `demo.local`                                                |
|  `OPENLDAP_GROUP_MAPPINGS`          | Maps LDAP Group to Nexus Role    | `Admins,nx-admin All,nx-anonymous`                          |
|  `OPENLDAP_HOST`                    | OpenLDAP Backend Address         | `127.0.0.1`                                                 |
|  `OPENLDAP_PORT`                    | OpenLDAP Bind Port               | `389` or `636` depending on `OPENLDAP_PROTO`                |
|  `OPENLDAP_PROTO`                   | OpenLDAP Proto                   | `ldap`                                                      |
|  `OPENLDAP_USERS_OBJECTCLASS`       | OpenLDAP Users ObjectClass       | `inetOrgPerson`                                             |

You can also set the following mount points by passing the `-v /host:/container` flag to Docker.

|  Volume mount point    | Description              |
| :--------------------- | ------------------------ |
|  `/nexus`              | Nexus Persisting Data    |
|  `/certs`              | Nexus CAs to load        |
