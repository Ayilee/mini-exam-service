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
      steps { 
        checkout scm 
      }
    }

    stage('Install') {
      steps {
        script {
          if (isUnix()) { 
            sh 'npm ci || npm install' 
          } else { 
            bat 'npm ci || npm install' 
          }
        }
      }
    }

    stage('Test') {
      steps {
        script {
          if (isUnix()) { 
            sh 'npm test' 
          } else { 
            bat 'npm test' 
          }
        }
      }
    }

    stage('Code Quality') {
      steps {
        script {
          if (isUnix()) { 
            sh 'npx eslint .' 
          } else { 
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
              # fail if health not UP
              grep -q '"status":"UP"' health.json
            '''
          } else {
            // Start app and fetch health.json (keep as is)
            bat 'powershell -NoProfile -Command "$p=(Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like ''*\\node.exe'' }); if($p){ $p | Stop-Process -Force -ErrorAction SilentlyContinue }; $proc=Start-Process node -ArgumentList ''server.js'' -PassThru -WindowStyle Hidden; Set-Content -Encoding ascii app.pid $proc.Id; Start-Sleep -Seconds 2; try { (Invoke-WebRequest -UseBasicParsing http://localhost:3000/health).Content | Set-Content -Encoding ascii health.json } catch { '' | Set-Content -Encoding ascii health.json }"'
            // Gate: parse JSON and fail if status != 'UP' (no regex)
            bat 'powershell -NoProfile -Command "$c = Get-Content -Raw health.json | ConvertFrom-Json; if ($c.status -eq ''UP'') { exit 0 } else { Write-Host ''HEALTH BAD:''; Write-Host ($c | ConvertTo-Json -Compress); exit 1 }"'
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
              bat 'powershell -NoProfile -Command "if (Test-Path app.pid) { Get-Content app.pid | ForEach-Object { try { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue } catch {} } }; Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue"'
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
