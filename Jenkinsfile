pipeline {
  agent any

  tools {
    nodejs 'Node20 (auto)'
  }

  options {
    skipDefaultCheckout(true)
    timestamps()
  }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Install') {
      steps {
        script {
          if (isUnix()) { sh 'npm ci || npm install' }
          else { bat 'npm ci || npm install' }
        }
      }
    }

    stage('Test') {
      steps {
        script {
          if (isUnix()) { sh 'npm test' }
          else { bat 'npm test' }
        }
      }
    }

    stage('Code Quality') {
      steps {
        script {
          if (isUnix()) { sh 'npx eslint .' }
          else { bat 'npx eslint .' }
        }
      }
    }

    stage('Build (artefact)') {
      steps {
        script {
          if (isUnix()) {
            sh 'tar -czf mini-exam-service.tgz *'
          } else {
            bat 'powershell -NoProfile -Command "Compress-Archive -Path * -DestinationPath mini-exam-service.zip -Force"'
          }
        }
        archiveArtifacts artifacts: 'mini-exam-service.*', fingerprint: true
      }
    }

    stage('Security (quick audit)') {
      steps {
        script {
          def status = isUnix()
            ? sh(script: 'npm audit --audit-level=high', returnStatus: true)
            : bat(script: 'npm audit --audit-level=high', returnStatus: true)
          if (status != 0) {
            unstable('npm audit found high-severity issues. See log.')
          }
        }
      }
    }

    // --- Drop-in Deploy block (Windows+Linux) ---
    stage('Deploy (Test)') {
      steps {
        script {
          if (isUnix()) {
            sh '''
              pkill -f "node server.js" || true
              nohup node server.js > jenkins-run.log 2>&1 &
              echo $! > app.pid
              sleep 2
              curl -s http://localhost:3000/health > health.json || true
              echo "HEALTH: $(cat health.json)"
              # Fail if health not UP
              grep -q '"status":"UP"' health.json
            '''
          } else {
            // Start and fetch health.json
            bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\start-and-health.ps1'
            // Gate: fail if status != UP
            bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\gate-health.ps1'
          }
        }
      }
      post {
        always {
          script {
            if (isUnix()) {
              sh 'if [ -f app.pid ]; then kill "$(cat app.pid)" 2>/dev/null || true; fi'
              sh 'pkill -f "node server.js" || true'
            } else {
              bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\stop-app.ps1'
            }
          }
          archiveArtifacts artifacts: 'jenkins-run.log,health.json', allowEmptyArchive: true
        }
      }
    }
    // --- End Deploy block ---
  }

  post {
    always {
      // Don’t fail the whole build if Windows can’t delete instantly
      cleanWs(deleteDirs: true, notFailBuild: true)
    }
  }
}
