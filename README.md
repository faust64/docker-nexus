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

|    Variable name                    |    Description                   | Default                     |
| :---------------------------------- | -------------------------------- | --------------------------- |
|  `NEXUS_ADMIN_PASSWORD`             | Nexus Admin Password             | `admin123`                  |
|  `NEXUS_ARTIFACTS_SERVICE_PASSWORD` | Nexus Jenkins-Artifacts Password | `undef`                     |
|  `NEXUS_DEPLOYER_SERVICE_PASSWORD`  | Nexus Jenkins-Deployer Password  | `undef`                     |
|  `NEXUS_JENKINS_ARTIFACTS_ACCOUNT`  | Nexus Jenkins-Artifacts Account  | `undef`                     |
|  `NEXUS_JENKINS_DEPLOYER_ACCOUNT`   | Nexus Jenkins-Deployer Account   | `undef`                     |

You can also set the following mount points by passing the `-v /host:/container` flag to Docker.

|  Volume mount point    | Description              |
| :--------------------- | ------------------------ |
|  `/nexus`              | Nexus Persisting Data    |
|  `/certs`              | Nexus CAs to load        |
