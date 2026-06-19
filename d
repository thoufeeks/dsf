pipeline {
agent any

```
tools {
    jdk 'jdk17'
}

environment {
    SCANNER_HOME = tool 'sonarqube-scanner'
}

stages {

    stage('Clean Workspace') {
        steps {
            cleanWs()
        }
    }

    stage('Checkout from Git') {
        steps {
            git branch: 'main', url: 'https://github.com/<repo>'
        }
    }

    stage('Sonarqube Analysis') {
        steps {
            withSonarQubeEnv('SonarQube-Server') {
                sh """
                ${SCANNER_HOME}/bin/sonar-scanner \
                -Dsonar.projectName=my-app \
                -Dsonar.projectKey=my-app
                """
            }
        }
    }

    stage('TRIVY FS SCAN') {
        steps {
            sh 'trivy fs . > trivyfs.txt'
        }
    }

    stage('Docker Build & Push') {
        steps {
            withDockerRegistry(
                credentialsId: 'dockerhub',
                url: 'https://index.docker.io/v1/'
            ) {
                sh '''
                docker build -t thoufeek/myapp:latest .
                docker push thoufeek/myapp:latest
                '''
            }
        }
    }

    stage('TRIVY Image Scan') {
        steps {
            sh 'trivy image thoufeek/myapp:latest > trivy-image.txt'
        }
    }

    stage('Deploy to Dev Docker Server') {
        steps {
            sshagent(['dev-server-ssh']) {
                sh '''
                ssh -o StrictHostKeyChecking=no ubuntu@DEV_SERVER_IP "

                docker pull thoufeek/myapp:latest

                docker stop myapp || true
                docker rm myapp || true

                docker run -d --name myapp \
                -p 80:80 \
                thoufeek/myapp:latest
                "
                '''
            }
        }
    }

    stage('Approval for Production') {
        steps {
            input 'Deploy to Production Kubernetes?'
        }
    }

    stage('Deploy to Kubernetes') {
        steps {
            dir('k8s') {
                withKubeConfig(
                    credentialsId: 'kubernetes'
                ) {
                    sh 'kubectl apply -f .'
                }
            }
        }
    }
}
```

}
