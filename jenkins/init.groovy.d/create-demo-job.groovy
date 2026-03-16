import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

def jenkins = Jenkins.get()
def jobName = "openhands-sre-demo"
def pipelineScript = new File("/workspace/openhands-sre/Jenkinsfile").text

WorkflowJob job = jenkins.getItem(jobName)
if (job == null) {
    job = jenkins.createProject(WorkflowJob, jobName)
}

job.setDefinition(new CpsFlowDefinition(pipelineScript, true))
job.setDisplayName("OpenHands SRE Demo")
job.setDescription("Post-remediation validation for the OpenHands incident demo. This job is triggered after OpenHands creates a remediation PR.")
job.save()

jenkins.save()
