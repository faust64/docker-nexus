# Nexus

WARNING: this repository is no longer maintained! As it was migrated to GitLab:
https://gitlab.com/synacksynack/opsperator/docker-nexus

(historically based on https://github.com/Accenture/adop-nexus)

Build with:

```
$ make build
```

Test locally:

```
$ make run
```

Environment variables and volumes
----------------------------------

The image recognizes the following environment variables that you can set during
initialization by passing `-e VAR=VALUE` to the Docker `run` command.

|    Variable name                     |    Description                   | Default                                                     |
| :----------------------------------- | -------------------------------- | ----------------------------------------------------------- |
|  `NEXUS_ADMIN_PASSWORD`              | Nexus Admin Password             | `admin123`                                                  |
|  `NEXUS_ARTIFACTS_SERVICE_PASSWORD`  | Nexus Jenkins-Artifacts Password | undef                                                       |
|  `NEXUS_BLOB_STORES`                 | Blob Stores to Provision         | undef                                                       |
|  `NEXUS_DEPLOYER_SERVICE_PASSWORD`   | Nexus Jenkins-Deployer Password  | undef                                                       |
|  `NEXUS_JENKINS_ARTIFACTS_ACCOUNT`   | Nexus Jenkins-Artifacts Account  | undef                                                       |
|  `NEXUS_JENKINS_DEPLOYER_ACCOUNT`    | Nexus Jenkins-Deployer Account   | undef                                                       |
|  `NEXUS_PROMETHEUS_ACCOUNT`          | Nexus Prometheus Account         | undef                                                       |
|  `NEXUS_PROMETHEUS_SERVICE_PASSWORD` | Nexus Prometheus Password        | undef                                                       |
|  `NEXUS_REPOSITORIES`                | Repositories to Provision        | undef                                                       |
|  `OPENLDAP_BASE`                     | OpenLDAP Base                    | seds `OPENLDAP_DOMAIN`, default produces `dc=demo,dc=local` |
|  `OPENLDAP_BIND_DN_RREFIX`           | OpenLDAP Bind DN Prefix          | `cn=nexus,ou=service`                                       |
|  `OPENLDAP_BIND_PW`                  | OpenLDAP Bind Password           | `secret`                                                    |
|  `OPENLDAP_DOMAIN`                   | OpenLDAP Domain Name             | `demo.local`                                                |
|  `OPENLDAP_GROUP_MAPPINGS`           | Maps LDAP Group to Nexus Role    | `Admins,nx-admin All,nx-anonymous`                          |
|  `OPENLDAP_HOST`                     | OpenLDAP Backend Address         | `127.0.0.1`                                                 |
|  `OPENLDAP_PORT`                     | OpenLDAP Bind Port               | `389` or `636` depending on `OPENLDAP_PROTO`                |
|  `OPENLDAP_PROTO`                    | OpenLDAP Proto                   | `ldap`                                                      |
|  `OPENLDAP_USERS_OBJECTCLASS`        | OpenLDAP Users ObjectClass       | `inetOrgPerson`                                             |

Provisioning
-------------

Repositories provisioning is a work in progress. I stuck to the few use cases
that matter for me, though there's a lot of stuff I did not implement.
So far, we may pass a list (space separated) of repository definitions (pipe
separated), ... which makes it quite impractical and ugly, ... of repositories
to provision. Valid combinations may include:

```
NEXUS_RERPOSITORIES="
    my-npm-proxy|npm|proxy|https://registry.npmjs.org|npmblob
    my-npm-hosted|npm|hosted|npmblob
    my-apt-proxy|apt|proxy|https://ftp.debian.org|buster|aptblob
    my-apt-hosted|apt|hosted|keyring|passphrase|buster|aptblob
    my-dkr-http-proxy|docker|proxy|https://docker.io|5001||dkrblob
    my-dkr-https-hosted|docker|hosted|5002|yes|dkrblob
    my-dkr-http-nolistener|docker|hosted|||dkrblob
    my-raw|raw|hosted|default"
```

Blob stores would need to be provisioned as well - and bear in mind the API
does allow to create repositories whose blob store does not exist:

```
NEXUS_BLOB_STORES="
    s3blobstore|s3-acces-key|s3-secret-key|s3-bucket|http://radosgw:8080|us-east-1
    npmblob aptblob dkrblob"
```

You can also set the following mount points by passing the `-v /host:/container` flag to Docker.

|  Volume mount point    | Description              |
| :--------------------- | ------------------------ |
|  `/nexus`              | Nexus Persisting Data    |
|  `/certs`              | Nexus CAs to load        |
