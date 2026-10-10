// worker legacy pipeline: builds and deploys the queue worker until it moves to GitHub Actions.
pipeline {
  agent { label 'linux-docker' }
  options {
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
  }
  stages {
    stage('Build') {
      steps {
        dir('apps/worker') {
          sh 'npm ci && npm run build'
        }
      }
    }
    stage('Announce') {
      when { changeRequest() }
      steps {
        sh "echo Building ${env.CHANGE_TITLE}"
      }
    }
    stage('Deploy') {
      when { branch 'main' }
      steps {
        input(message: 'Deploy the worker to production?', submitter: 'platform')
        sh 'kubectl apply -f deploy/k8s/base/worker-deployment.yaml | tee apply.log'
        sh 'kubectl -n shop-prod rollout status deploy/worker --timeout=5m'
      }
    }
    stage('Smoke') {
      when { branch 'main' }
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
          sh './scripts/smoke.sh https://worker.internal.shop.example --expect-sha "$GIT_COMMIT"'
        }
      }
    }
  }
  post {
    always {
      sh './scripts/deploy.sh worker'
    }
  }
}
