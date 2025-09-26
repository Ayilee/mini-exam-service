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
          if (isUnix()) {
            // Jest -> JUnit XML (needs devDep: jest-junit)
            sh 'mkdir -p reports/junit'
            sh 'JEST_JUNIT_OUTPUT=reports/junit/junit.xml npm test -- --coverage --reporters=default --reporters=jest-junit'
          } else {
            // Windows: make folder and set env var for jest-junit output
            bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force reports\\junit | Out-Null"'
            bat 'powershell -NoProfile -Command "$env:JEST_JUNIT_OUTPUT=''reports\\junit\\junit.xml''; npm test -- --coverage --reporters=default --reporters=jest-junit"'
          }
        }
      }
    }

    stage('Code Quality') {
      steps {
        script {
          if (isUnix()) {
            // Keep console lint + also write Checkstyle XML for Jenkins
            sh 'mkdir -p reports/eslint'
            sh 'npx eslint . -f checkstyle -o reports/eslint/checkstyle.xml || true'
          } else {
            bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force reports\\eslint | Out-Null"'
            bat 'npx eslint . -f checkstyle -o reports\\eslint\\checkstyle.xml || exit /b 0'
          }
          // (Optional) also keep plain console output:
          if (isUnix()) { sh 'npx eslint .' } else { bat 'npx eslint .' }
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

    // --- Deploy (Windows+Linux) ---
    stage('Deploy (Test)') {
      steps {
        script {
          if (isUnix()) {
            sh 'pkill -f "node server.js" || true'
            sh 'nohup node server.js > jenkins-run.log 2>&1 &'
            sh 'echo $! > app.pid'
            sh 'sleep 2'
            sh 'curl -s http://localhost:3000/health > health.json || true'
            sh 'echo "HEALTH: $(cat health.json)"'
            // Fail if health not UP
            sh 'grep -q \'"status":"UP"\' health.json'
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
    // --- End Deploy ---
  }

  post {
    always {
      // Publish test results (JUnit)
      junit testResults: 'reports/junit/junit.xml', allowEmptyResults: true
      // Archive CI reports for evidence (JUnit + ESLint)
      archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true

      // Don’t fail the whole build if Windows can’t delete instantly
      cleanWs(deleteDirs: true, notFailBuild: true)
    }
  }
}
