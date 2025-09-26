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
            sh 'mkdir -p reports/junit'
            sh 'JEST_JUNIT_OUTPUT=reports/junit/junit.xml npm test -- --coverage --reporters=default --reporters=jest-junit'
          } else {
            bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force reports\\junit | Out-Null"'
            withEnv(['JEST_JUNIT_OUTPUT=reports\\junit\\junit.xml']) {
              bat 'npm test -- --coverage --reporters=default --reporters=jest-junit'
            }
          }
        }
      }
    }

    stage('Code Quality') {
      steps {
        script {
          if (isUnix()) {
            sh 'mkdir -p reports/eslint'
            sh 'npx eslint . -f checkstyle -o reports/eslint/checkstyle.xml || true'
            sh 'npx eslint .'
          } else {
            bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force reports\\eslint | Out-Null"'
            bat 'npx eslint . -f checkstyle -o reports\\eslint\\checkstyle.xml || exit /b 0'
            bat 'npx eslint .'
          }
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
            sh '''
              pkill -f "node server.js" || true
              nohup node server.js > jenkins-run.log 2>&1 &
              echo $! > app.pid
              sleep 2
              curl -s http://localhost:3000/health > health.json || true
              echo "HEALTH: $(cat health.json)"
              grep -q '"status":"UP"' health.json
            '''
          } else {
            bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\start-and-health.ps1'
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

    // --- Release (approval) ---
    stage('Release (approval)') {
      when { branch 'main' } // optional: only release from main
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          input message: 'Promote the current artifact to PRODUCTION?', ok: 'Release'
        }
        script {
          if (isUnix()) {
            sh 'mkdir -p releases && cp mini-exam-service.tgz releases/mini-exam-service-prod.tgz'
          } else {
            bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force releases | Out-Null; Copy-Item mini-exam-service.zip releases\\mini-exam-service-prod.zip -Force"'
          }
        }
        archiveArtifacts artifacts: 'releases/**', fingerprint: true
      }
    }

    // --- Monitoring (smoke) ---
    stage('Monitoring (smoke)') {
      steps {
        script {
          if (isUnix()) {
            sh '''
              rm -f monitor.log || true
              for i in $(seq 1 4); do
                ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health || true)
                body=$(curl -s http://localhost:3000/health || echo '')
                echo "$ts status:$code body:$body" >> monitor.log
                sleep 30
              done
            '''
          } else {
            bat 'powershell -NoProfile -Command "Remove-Item -ErrorAction SilentlyContinue monitor.log; for ($i=1; $i -le 4; $i++) { $ts=(Get-Date).ToUniversalTime().ToString(''yyyy-MM-ddTHH:mm:ssZ''); try { $resp=Invoke-WebRequest -UseBasicParsing http://localhost:3000/health; $code=$resp.StatusCode.value__; $body=$resp.Content } catch { $code=0; $body=\\"\\" }; Add-Content -Encoding ascii monitor.log \\"$ts status:$code body:$body\\"; Start-Sleep -Seconds 30 }"'
          }
        }
      }
      post {
        always {
          archiveArtifacts artifacts: 'monitor.log', allowEmptyArchive: true
        }
      }
    }
  }

  post {
    always {
      junit testResults: 'reports/junit/junit.xml', allowEmptyResults: true
      archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
      cleanWs(deleteDirs: true, notFailBuild: true)
    }
  }
}
