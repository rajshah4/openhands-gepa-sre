pipeline {
  agent any

  environment {
    UV_CACHE_DIR = "${WORKSPACE}/.uv-cache"
    UV_PROJECT_ENVIRONMENT = "${WORKSPACE}/.venv-jenkins"
    APP_BASE_URL = 'http://host.docker.internal:15000'
    MCP_HEALTH_URL = 'http://127.0.0.1:8082/'
    MCP_URL = 'http://127.0.0.1:8082/mcp'
    DEMO_REPO = '/workspace/openhands-sre'
    DEMO_PATH = '/usr/local/bin:/usr/bin:/bin'
    APP_HOST = 'host.docker.internal'
    MCP_HOST = '127.0.0.1'
    MCP_PORT = '8082'
  }

  stages {
    stage('Install Python Dependencies') {
      steps {
        sh 'export PATH="$DEMO_PATH:$PATH"; cd "$DEMO_REPO" && uv sync --frozen'
      }
    }

    stage('Start Demo Stack') {
      steps {
        sh 'export PATH="$DEMO_PATH:$PATH"; cd "$DEMO_REPO" && APP_HOST="$APP_HOST" MCP_HOST="$MCP_HOST" MCP_PORT="$MCP_PORT" PYTHON_BIN="$UV_PROJECT_ENVIRONMENT/bin/python" RUN_LOCAL_JENKINS=0 RUN_PREFLIGHT=0 ./scripts/start_demo.sh'
      }
    }

    stage('Post-Remediation Validation') {
      steps {
        sh 'export PATH="$DEMO_PATH:$PATH"; cd "$DEMO_REPO" && APP_BASE_URL="$APP_BASE_URL" MCP_HEALTH_URL="$MCP_HEALTH_URL" MCP_URL="$MCP_URL" START_STACK=0 ./scripts/jenkins_verify_demo.sh'
      }
    }
  }

  post {
    always {
      sh 'export PATH="$DEMO_PATH:$PATH"; docker ps --filter name=openhands-gepa-demo || true'
      sh 'export PATH="$DEMO_PATH:$PATH"; test -f /tmp/mcp_server.log && tail -n 100 /tmp/mcp_server.log || true'
    }
  }
}
