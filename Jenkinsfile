pipeline {
  agent any
  options {
    timestamps()
    skipDefaultCheckout(true)
  }

  environment {
    NODEJS = 'NodeJS_20'           
    SNYK_ORG = 'ayilee'
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
        always {
          junit 'reports/junit/*.xml'
        }
      }
    }

    stage('Code Quality (ESLint)') {
      tools { nodejs "${env.NODEJS}" }
      steps {
        bat 'powershell -NoProfile -Command "New-Item -ItemType Directory -Force reports\\eslint | Out-Null"'
        bat 'npm i -D eslint-formatter-checkstyle'
        bat 'npx eslint . -f checkstyle -o reports\\eslint\\checkstyle.xml || exit /b 0'
        bat 'npx eslint . || exit /b 0'
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
      environment { SNYK_TOKEN = credentials('snyk-token') }
      steps {
        bat 'if not exist reports mkdir reports'
        bat 'npm i -g snyk'
        bat 'snyk auth %SNYK_TOKEN%'
        bat 'snyk test --org=%SNYK_ORG% --file=package-lock.json --severity-threshold=low || exit /b 0'
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
        expression {
          return (bat(returnStatus: true, script: 'where docker >NUL 2>&1') == 0)
        }
      }
      environment {
        IMG = "mini-exam:${env.BUILD_NUMBER}"
      }
      steps {
        echo "Docker available; running container test as ${IMG}"
        bat 'docker version'
        bat 'docker build -t mini-exam:%BUILD_NUMBER% -f dockerfile .'
        bat 'docker run --rm -d -p 8080:8080 --name mini_exam mini-exam:%BUILD_NUMBER%'
        bat 'powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\gate-health.ps1'
      }
      post {
        always {
          
          script {
            bat(returnStatus: true, script: 'docker ps -a --format "{{.Names}}" | findstr /I mini_exam >NUL && docker rm -f mini_exam || ver >NUL')
            bat(returnStatus: true, script: 'docker image inspect mini-exam:%BUILD_NUMBER% >NUL 2>&1 && docker rmi -f mini-exam:%BUILD_NUMBER% || ver >NUL')
          }
        }
      }
    }

    stage('Sonar (quality)') {
      when { expression { return env.SONAR_HOST_URL != null } }
      steps {
        echo 'Run your Sonar scanner here (guarded if not configured).'
      }
    }

    stage('Release (approval)') {
      steps {
        input message: 'Promote this build?', ok: 'Release'
        echo 'Release steps go here'
      }
    }

    stage('Monitoring (smoke)') {
      steps {
        echo 'Run smoke checks against the deployed target'
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'reports/**/*', fingerprint: true, onlyIfSuccessful: false
      cleanWs()
    }
  }
}
