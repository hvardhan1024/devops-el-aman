pipeline {
    agent any

    environment {
        DOCKER_IMAGE = "harshavardhan873/backend"
        DOCKER_TAG = "v${BUILD_NUMBER}"
    }

    stages {
        stage('Clone Repository') {
            steps {
                git branch: 'main', url: 'https://github.com/hvardhan1024/devops-el'
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('backend-green') {
                    sh "docker build -t ${DOCKER_IMAGE}:${DOCKER_TAG} ."
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub-creds',
                    passwordVariable: 'dockerpass',
                    usernameVariable: 'dockeruser'
                )]) {
                    sh 'echo $dockerpass | docker login -u $dockeruser --password-stdin'
                    sh "docker push ${DOCKER_IMAGE}:${DOCKER_TAG}"
                }
            }
        }
    }

    post {
        success {
            echo "✅ Build #${BUILD_NUMBER} successful! Image: ${DOCKER_IMAGE}:${DOCKER_TAG}"
        }
        always {
            sh "docker rmi -f ${DOCKER_IMAGE}:${DOCKER_TAG} || true"
            cleanWs()
        }
    }
}
