import hudson.security.FullControlOnceLoggedInAuthorizationStrategy
import jenkins.model.Jenkins
import jenkins.install.InstallState
import hudson.security.HudsonPrivateSecurityRealm
def jenkins = Jenkins.get()

def realm = new HudsonPrivateSecurityRealm(false)
if (realm.getUser("admin") == null) {
    realm.createAccount("admin", "admin")
}
jenkins.setSecurityRealm(realm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
jenkins.setAuthorizationStrategy(strategy)
jenkins.setCrumbIssuer(null)

jenkins.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

jenkins.save()
