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
          else          { bat 'npm ci || npm install' }
        }
      }
    }

    stage('Test') {
      steps {
        script {
          if (isUnix()) {
            sh '''
              set -e
              mkdir -p reports/junit
              JEST_JUNIT_OUTPUT=reports/junit/junit.xml \
              npm test -- --coverage --reporters=default --reporters=jest-junit
              [ -f junit.xml ] && mv -f junit.xml reports/junit/junit.xml || true
              echo "===== reports/junit ====="
              ls -l reports/junit || true
            '''
          } else {
            bat '''
              if not exist reports\\junit mkdir reports\\junit
              set "JEST_JUNIT_OUTPUT=reports\\junit\\junit.xml"
              npm test -- --coverage --reporters=default --reporters=jest-junit
              if exist junit.xml move /Y junit.xml reports\\junit\\junit.xml
              echo ===== Contents of reports\\junit =====
              dir reports\\junit
            '''
          }
        }
      }
    }

    stage('Code Quality (ESLint)') {
      steps {
        script {
          if (isUnix()) {
            sh 'mkdir -p reports/eslint'
            sh 'npx eslint . -f checkstyle -o reports/eslint/checkstyle.xml || true'
            sh 'npx eslint .'
          } else {
            bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force reports\\eslint | Out-Null"'
            bat 'npm i -D eslint-formatter-checkstyle'
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

    stage('Security (npm audit)') {
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

    stage('Security (Snyk)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          script {
            if (isUnix()) {
              sh '''
                mkdir -p reports
                npm i -g snyk
                snyk auth "$SNYK_TOKEN" || true
                snyk test --severity-threshold=high || true
                snyk test --json --severity-threshold=high > reports/snyk.json || true
              '''
            } else {
              bat '''
                if not exist reports mkdir reports
                call npm i -g snyk
                call snyk auth %SNYK_TOKEN% || exit /b 0
                call snyk test --severity-threshold=high || exit /b 0
                call snyk test --json --severity-threshold=high > reports\\snyk.json || exit /b 0
              '''
            }
          }
        }
      }
    }

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

    stage('Deploy (Docker Test)') {
      steps {
        script {
          def img = "mini-exam-service:${env.BUILD_NUMBER}"
          if (isUnix()) {
            def dockerOK = sh(script: 'docker --version >/dev/null 2>&1', returnStatus: true) == 0
            if (!dockerOK) { echo 'Docker not available; skipping.'; return }
            sh """
              set -euxo pipefail
              docker build -t ${img} .
              docker ps -q --filter 'publish=3000' | xargs -r docker stop || true
              docker run -d --rm -p 3000:3000 --name mini-exam-${BUILD_NUMBER} ${img}
              sleep 2
              curl -s http://localhost:3000/health > health.json || true
              echo "HEALTH (Docker): $(cat health.json || true)"
              grep -q '"status":"UP"' health.json
            """
          } else {
            def dockerOK = bat(script: 'docker --version', returnStatus: true) == 0
            if (!dockerOK) { echo 'Docker not available; skipping.'; return }
            bat """
              docker build -t ${img} .
              for /f "tokens=*" %%i in ('docker ps -q --filter "publish=3000"') do docker stop %%i
              docker run -d --rm -p 3000:3000 --name mini-exam-%BUILD_NUMBER% ${img}
              powershell -NoProfile -Command "Start-Sleep -Seconds 2; try { (Invoke-WebRequest -UseBasicParsing http://localhost:3000/health).Content | Set-Content -Encoding ascii health.json } catch { '' | Set-Content -Encoding ascii health.json }"
              powershell -NoProfile -Command "$c = Get-Content -Raw health.json | ConvertFrom-Json; if ($c.status -eq 'UP') { exit 0 } else { Write-Host 'HEALTH BAD:'; Write-Host ($c | ConvertTo-Json -Compress); exit 1 }"
            """
          }
        }
      }
      post {
        always {
          script {
            if (isUnix()) {
              sh 'docker ps -q --filter "name=mini-exam-" | xargs -r docker stop || true'
            } else {
              bat 'for /f "tokens=*" %%i in (\'docker ps -q --filter "name=mini-exam-"\') do docker stop %%i'
            }
          }
          archiveArtifacts artifacts: 'health.json', allowEmptyArchive: true
        }
      }
    }

    stage('Sonar (quality)') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          script {
            if (isUnix()) {
              sh '''
                npx --yes sonar-scanner \
                  -Dsonar.host.url=https://sonarcloud.io \
                  -Dsonar.login=$SONAR_TOKEN
              '''
            } else {
              bat '''
                npx --yes sonar-scanner ^
                  -Dsonar.host.url=https://sonarcloud.io ^
                  -Dsonar.login=%SONAR_TOKEN%
              '''
            }
          }
        }
      }
    }

    stage('Release (approval)') {
      when { branch 'main' }
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
            bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\monitor.ps1'
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
      junit testResults: 'reports/junit/*.xml', allowEmptyResults: true
      archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
      cleanWs(deleteDirs: true, notFailBuild: true)
    }
  }
}
