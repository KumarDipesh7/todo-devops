pipeline {
    agent any

    environment {
        IMAGE_TAG      = "build-${BUILD_NUMBER}"
        BACKEND_IMAGE  = "todo-backend"
        FRONTEND_IMAGE = "todo-frontend"
        WORKSPACE_DIR  = "/home/dipeshkumar/devops/todo-devops"
        JAVA_HOME      = "/usr/lib/jvm/java-17-openjdk-amd64"
        PATH           = "/usr/lib/jvm/java-17-openjdk-amd64/bin:${env.PATH}"
    }

    stages {

        stage('Checkout') {
            steps {
                echo "Checking out source code..."
                checkout scm
            }
        }

        stage('Build (Maven)') {
            steps {
                echo "Building JAR with Maven..."
                sh 'mvn clean package -DskipTests -q'
                echo "JAR created successfully."
            }
            post {
                failure {
                    echo "Maven build failed! Fix compilation errors."
                }
            }
        }

        stage('Docker Build') {
            steps {
                echo "Building Docker images..."
                sh """
                    docker build -t ${BACKEND_IMAGE}:${IMAGE_TAG} -t ${BACKEND_IMAGE}:latest .
                    docker build -t ${FRONTEND_IMAGE}:${IMAGE_TAG} -t ${FRONTEND_IMAGE}:latest ./frontend
                """
            }
        }

        stage('Deploy') {
            steps {
                echo "Deploying with Docker Compose..."
                sh """
                    cd ${WORKSPACE_DIR}
                    docker-compose down --remove-orphans
                    docker-compose up -d --build
                """
            }
        }

        stage('Smoke Test') {
            steps {
                echo "Waiting for backend to be ready..."
                sh '''
                    for i in $(seq 1 15); do
                        STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8082/todos/health)
                        if [ "$STATUS" = "200" ]; then
                            echo "Health check passed!"
                            exit 0
                        fi
                        echo "Waiting... attempt $i"
                        sleep 3
                    done
                    echo "Health check failed after 45s"
                    exit 1
                '''
            }
        }
    }

    post {
        success {
            echo "Deployment successful! App running at http://localhost:3001"
        }
        failure {
            echo "Pipeline failed. Check logs above."
        }
        always {
            echo "Build #${BUILD_NUMBER} finished."
        }
    }
}
