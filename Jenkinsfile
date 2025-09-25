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
            // Start app and fetch health.json (IMPORTANT: escape $ for Groovy)
            bat "powershell -NoProfile -Command \"Get-Process -Name node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; \\$proc = Start-Process node -ArgumentList 'server.js' -PassThru -WindowStyle Hidden; Set-Content -Encoding ascii app.pid \\$proc.Id; Start-Sleep -Seconds 2; try { (Invoke-WebRequest -UseBasicParsing http://localhost:3000/health).Content | Set-Content -Encoding ascii health.json } catch { '' | Set-Content -Encoding ascii health.json }\""
            bat "powershell -NoProfile -Command \"\\$c = Get-Content -Raw health.json | ConvertFrom-Json; if (\\$c.status -eq 'UP') { exit 0 } else { Write-Host 'HEALTH BAD:'; Write-Host (\\$c | ConvertTo-Json -Compress); exit 1 }\""
          }
        }
      }
      post {
        always {
          script {
            if (isUnix()) {
              sh 'if [ -f app.pid ]; then kill \"$(cat app.pid)\" 2>/dev/null || true; fi'
              sh 'pkill -f "node server.js" || true'
            } else {
              // Robust Windows cleanup; note the escaped $ and $_
              bat "powershell -NoProfile -Command \"\\$ErrorActionPreference='SilentlyContinue'; if (Test-Path app.pid) { Get-Content app.pid | ForEach-Object { try { Stop-Process -Id \\$_ -Force } catch {} } }; Get-Process node | Stop-Process -Force; exit 0\""
            }
          }
          archiveArtifacts artifacts: 'jenkins-run.log,health.json', allowEmptyArchive: true

          // Give Windows a tiny pause so file locks release
          script { if (!isUnix()) bat 'ping -n 3 127.0.0.1 >NUL' }
        }
      }
    }
  }

  post {
    always {
      // Don’t fail the whole build if Windows can’t delete instantly
      cleanWs(deleteDirs: true, notFailBuild: true)
    }
  }
}
