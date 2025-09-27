pipeline {
  agent any

  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  environment {
    NODEJS = 'NodeJS_20'
  }

  stages {
    stage('Declarative: Tool Install') {
      steps { echo 'Tools resolved via "tools" blocks in later stages.' }
    }

    stage('Checkout') {
      tools { nodejs "${env.NODEJS}" }
      steps {
        checkout([
          $class: 'GitSCM',
          branches: [[name: '*/main']],
          userRemoteConfigs: [[
            url: 'https://github.com/Ayilee/mini-exam-service.git',
            credentialsId: 'github-ayilee'
          ]]
        ])
      }
    }

    stage('Install') {
      tools { nodejs "${env.NODEJS}" }
      steps {
        bat 'npm ci || npm install'
      }
    }

    stage('Test') {
      tools { nodejs "${env.NODEJS}" }
      steps {
        bat 'if not exist reports\\junit mkdir reports\\junit'
        bat 'set "JEST_JUNIT_OUTPUT=reports\\junit\\junit.xml" && npm test -- --coverage --reporters=default --reporters=jest-junit'
      }
      post {
        always { junit 'reports/junit/*.xml' }
      }
    }

    stage('Code Quality (ESLint)') {
      tools { nodejs "${env.NODEJS}" }
      steps {
        bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force reports\\eslint | Out-Null"'
        bat 'npm i -D eslint-formatter-checkstyle'
        bat 'npx eslint . -f checkstyle -o reports\\eslint\\checkstyle.xml --ignore-pattern coverage || exit /b 0'
        bat 'npx eslint . --ignore-pattern coverage || exit /b 0'
      }
    }

    stage('Build (artefact)') {
      steps {
        bat 'powershell -NoProfile -Command "Compress-Archive -Path * -DestinationPath mini-exam-service.zip -Force"'
        archiveArtifacts artifacts: 'mini-exam-service.zip', fingerprint: true
      }
    }

    stage('Security (npm audit)') {
      steps { bat 'npm audit --audit-level=high' }
    }

    stage('Security (Snyk)') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token', variable: 'SNYK_TOKEN')]) {
          bat '''
            if not exist reports mkdir reports
            npx --yes snyk@latest auth %SNYK_TOKEN% || exit /b 0
            npx --yes snyk@latest test --severity-threshold=high || exit /b 0
            npx --yes snyk@latest test --json --severity-threshold=high > reports\\snyk.json || exit /b 0
          '''
        }
      }
    }

    stage('Deploy (Test)') {
      steps {
        bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\start-and-health.ps1'
        bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\gate-health.ps1'
      }
      post {
        always {
          bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\stop-app.ps1 || ver >NUL'
          archiveArtifacts artifacts: 'reports/**/*', fingerprint: true, onlyIfSuccessful: false
        }
      }
    }

    stage('Deploy (Docker Test)') {
      when {
        expression { bat(returnStatus: true, script: 'where docker >NUL 2>&1') == 0 }
      }
      environment {
        IMG = "mini-exam-service:%BUILD_NUMBER%"
      }
      steps {
        echo "Docker available; running container test as ${env.IMG}"
        bat 'docker build -t %IMG% -f dockerfile .'
        bat 'for /f "tokens=*" %%i in (\'docker ps -q --filter "publish=3000"\') do docker stop %%i'
        bat 'docker run -d --rm -p 3000:3000 --name mini-exam-%BUILD_NUMBER% %IMG%'
        bat 'powershell -NoProfile -Command "Start-Sleep -Seconds 2; try { (Invoke-WebRequest -UseBasicParsing http://localhost:3000/health).Content | Set-Content -Encoding ascii health.json } catch { \'\'}"'
        bat 'powershell -NoProfile -Command "$c = Get-Content -Raw health.json | ConvertFrom-Json; if ($c.status -eq \'UP\') { exit 0 } else { exit 1 }"'
      }
      post {
        always {
          bat 'for /f "tokens=*" %%i in (\'docker ps -q --filter "name=mini-exam-"\') do docker stop %%i'
          archiveArtifacts artifacts: 'health.json', allowEmptyArchive: true
        }
      }
    }

    stage('Sonar (quality)') {
      steps {
        withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
          bat '''
            npx --yes sonar-scanner ^
              -Dsonar.host.url=https://sonarcloud.io ^
              -Dsonar.token=%SONAR_TOKEN%
          '''
        }
      }
    }

    stage('Release (approval)') {
      steps {
        input message: 'Promote this build?', ok: 'Release'
        echo 'Release steps go here'
      }
    }

    stage('Monitoring (smoke)') {
      steps { echo 'Run smoke checks against the deployed target' }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'reports/**/*', fingerprint: true, onlyIfSuccessful: false
      cleanWs()
    }
  }
}
