import org.sonatype.nexus.repository.config.Configuration
import org.sonatype.nexus.blobstore.api.BlobStoreManager
import org.sonatype.nexus.repository.storage.WritePolicy

repository.createNpmHosted('npm-internal')
repository.createNpmProxy('npmjs-org', 'https://registry.npmjs.org')
repository.createNpmGroup('npm-all', ['npmjs-org', 'npm-internal'])

keypass = "signing secret"
keypair =  """
-----BEGIN PGP PRIVATE KEY BLOCK-----
SOME PRIVATE KEY GOES HERE
-----END PGP PRIVATE KEY BLOCK-----
"""

repository.createRepository(new Configuration(
        repositoryName: "jenkins-artifacts",
        recipeName: "apt-hosted",
        online: true,
        attributes: [
                storage: [
                        blobStoreName: BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
                        writePolicy: WritePolicy.ALLOW,
                        strictContentTypeValidation: true
		    ] as Map,
                apt: [
                        distribution : 'stable',
                        flat : false
		    ] as Map,
                aptSigning: [
                        keypair:  keypair.trim(),
                        passphrase: keypass
		    ] as Map,
                aptHosted: [
                        assetHistoryLimit: null
		    ] as Map
	    ] as Map
    ))

repository.createRepository(new Configuration(
        repositoryName: "debian-main",
        recipeName: "apt-proxy",
        online: true,
        attributes: [
                storage: [
                        blobStoreName: BlobStoreManager.DEFAULT_BLOBSTORE_NAME,
                        writePolicy: WritePolicy.ALLOW,
                        strictContentTypeValidation: true
		    ] as Map,
                apt: [
                        distribution : 'xenial',
                        flat : false
		    ] as Map,
                httpclient   : [
                        connection: [
                                blocked  : false,
                                autoBlock: true
			    ] as Map
		    ] as Map,
                proxy: [
                        remoteUrl: 'http://ftp.debian.org/debian/',
                        contentMaxAge: 0,
                        metaDataMaxAge: 0
		    ] as Map,
                negativeCache: [
                        enabled   : true,
                        timeToLive: 1440
		    ] as Map,
	    ] as Map
    ))
