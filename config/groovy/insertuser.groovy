import groovy.json.JsonSlurper
import org.sonatype.nexus.security.user.UserManager
import org.sonatype.nexus.security.role.NoSuchRoleException
import org.sonatype.nexus.security.user.UserNotFoundException

parsed_args = new JsonSlurper().parseText(args)

authManager = security.getSecuritySystem().getAuthorizationManager(UserManager.DEFAULT_SOURCE)

def existingRole = null

try {
    existingRole = authManager.getRole(parsed_args.role)
} catch (NoSuchRoleException ignored) {
    // could not find role
}

if (existingRole != null) {
    try {
	user = security.securitySystem.getUser(parsed_args.username);
	user.setFirstName(parsed_args.firstname)
	user.setLastName(parsed_args.lastname)
	user.setEmailAddress(parsed_args.email)
	security.securitySystem.updateUser(user)
	security.setUserRoles(parsed_args.username, [ parsed_args.role ])
	security.securitySystem.changePassword(parsed_args.username, parsed_args.password)
    } catch (UserNotFoundException e) {
	user = security.addUser(parsed_args.username, parsed_args.firstname, parsed_args.lastname, parsed_args.email, true, parsed_args.password, [ parsed_args.role ])
    }
}
