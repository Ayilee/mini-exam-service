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
          // Mark UNSTABLE (yellow) if high vulns appear, don’t fail the whole build
          def status = isUnix()
            ? sh(script: 'npm audit --audit-level=high', returnStatus: true)
            : bat(script: 'npm audit --audit-level=high', returnStatus: true)
          if (status != 0) {
            unstable('npm audit found high-severity issues. See log.')
          }
        }
      }
    }

    stage('Deploy (Test)') {
      steps {
        script {
          if (isUnix()) {
            sh '''
              # stop any previous run
              pkill -f "node server.js" || true

              # start app in background and write PID
              nohup node server.js > jenkins-run.log 2>&1 &
              echo $! > app.pid

              # give it a moment
              sleep 2

              # health check
              curl -s http://localhost:3000/health > health.json || true
              echo "HEALTH: $(cat health.json)"
            '''
            // fail stage if health not UP
            sh 'grep -q \\"status\\":\\"UP\\" health.json'
          } else {
            // Windows PowerShell
            bat '''
              powershell -NoProfile -Command ^
                "Get-Process -Name node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like '*server.js*' } | Stop-Process -Force -ErrorAction SilentlyContinue; ^
                 $p = Start-Process node -ArgumentList 'server.js' -PassThru -WindowStyle Hidden; ^
                 $p.Id | Out-File -Encoding ascii app.pid; ^
                 Start-Sleep -Seconds 2; ^
                 try { $r = Invoke-WebRequest -UseBasicParsing http://localhost:3000/health; $r.Content | Out-File -Encoding ascii health.json } catch { '' | Out-File health.json }"
            '''
            // fail stage if health not UP
            bat '''
              findstr /C:"\\"status\\":\\"UP\\"" health.json > NUL
              if errorlevel 1 exit /b 1
            '''
          }
        }
      }
      post {
        always {
          script {
            if (isUnix()) {
              sh '''
                if [ -f app.pid ]; then kill $(cat app.pid) 2>/dev/null || true; fi
                pkill -f "node server.js" || true
              '''
            } else {
              bat '''
                if exist app.pid for /f %%p in (app.pid) do taskkill /PID %%p /F >NUL 2>&1
                taskkill /IM node.exe /F >NUL 2>&1
              '''
            }
          }
          archiveArtifacts artifacts: 'jenkins-run.log,health.json', allowEmptyArchive: true
        }
      }
    }
  }

  post {
    always { cleanWs() }
  }
}
