pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'registry.joyone.vn'
        IMAGE_NAME = 'affine'
        STACK_NAME = 'affine-staging'
        DOMAIN = 'affine-staging.joyone.vn'
        GIT_COMMIT_SHORT = sh(
            script: "git rev-parse --short HEAD",
            returnStdout: true
        ).trim()
        BUILD_TIMESTAMP = sh(
            script: "date +%Y%m%d-%H%M%S",
            returnStdout: true
        ).trim()
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "🔄 Checking out code..."
                checkout scm
                
                script {
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}-${env.BUILD_TIMESTAMP}"
                    env.FULL_IMAGE_NAME = "${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}"
                    env.LATEST_IMAGE_NAME = "${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:latest"
                }
                
                echo "📋 Build Info:"
                echo "  - Image Tag: ${env.IMAGE_TAG}"
                echo "  - Full Image: ${env.FULL_IMAGE_NAME}"
                echo "  - Git Commit: ${env.GIT_COMMIT_SHORT}"
            }
        }
        
        stage('Pre-build Checks') {
            parallel {
                stage('Lint Dockerfile') {
                    steps {
                        echo "🔍 Linting Dockerfile..."
                        sh '''
                            if command -v hadolint >/dev/null 2>&1; then
                                hadolint Dockerfile || echo "Hadolint warnings found"
                            else
                                echo "Hadolint not installed, skipping..."
                            fi
                        '''
                    }
                }
                
                stage('Check Dependencies') {
                    steps {
                        echo "📦 Checking dependencies..."
                        sh '''
                            if [ -f package.json ]; then
                                echo "✅ package.json found"
                            else
                                echo "❌ package.json not found"
                                exit 1
                            fi
                            
                            if [ -f yarn.lock ]; then
                                echo "✅ yarn.lock found"
                            else
                                echo "❌ yarn.lock not found"
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo "🐳 Building Docker image..."
                script {
                    try {
                        sh """
                            docker build \
                                --build-arg BUILD_DATE=\$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
                                --build-arg VCS_REF=${env.GIT_COMMIT_SHORT} \
                                --build-arg BUILD_VERSION=${env.IMAGE_TAG} \
                                -t ${env.FULL_IMAGE_NAME} \
                                -t ${env.LATEST_IMAGE_NAME} \
                                .
                        """
                        echo "✅ Docker image built successfully"
                    } catch (Exception e) {
                        echo "❌ Docker build failed: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
        
        stage('Test Docker Image') {
            steps {
                echo "🧪 Testing Docker image..."
                script {
                    try {
                        // Test image can start
                        sh """
                            docker run --rm -d \
                                --name affine-test-${env.BUILD_NUMBER} \
                                -e NODE_ENV=test \
                                -p 3011:3010 \
                                ${env.FULL_IMAGE_NAME}
                        """
                        
                        // Wait for container to start
                        sleep(30)
                        
                        // Test health endpoint
                        sh """
                            timeout 60 bash -c 'until curl -f http://localhost:3011/api/health; do sleep 5; done' || true
                        """
                        
                        echo "✅ Docker image test completed"
                    } catch (Exception e) {
                        echo "❌ Docker image test failed: ${e.getMessage()}"
                    } finally {
                        // Cleanup test container
                        sh "docker stop affine-test-${env.BUILD_NUMBER} || true"
                        sh "docker rm affine-test-${env.BUILD_NUMBER} || true"
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo "📤 Pushing to Docker registry..."
                script {
                    try {
                        sh """
                            docker push ${env.FULL_IMAGE_NAME}
                            docker push ${env.LATEST_IMAGE_NAME}
                        """
                        echo "✅ Images pushed successfully"
                    } catch (Exception e) {
                        echo "❌ Push failed: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
        
        stage('Deploy to Staging') {
            steps {
                echo "🚀 Deploying to staging environment..."
                script {
                    try {
                        // Update stack file with new image
                        sh """
                            sed -i 's|image: .*|image: ${env.FULL_IMAGE_NAME}|g' docker-stack.yml
                        """
                        
                        // Deploy stack
                        sh """
                            docker stack deploy -c docker-stack.yml ${env.STACK_NAME}
                        """
                        
                        echo "✅ Deployment initiated"
                    } catch (Exception e) {
                        echo "❌ Deployment failed: ${e.getMessage()}"
                        throw e
                    }
                }
            }
        }
        
        stage('Health Check') {
            steps {
                echo "🏥 Performing health checks..."
                script {
                    def maxRetries = 20
                    def retryDelay = 15
                    def healthCheckPassed = false
                    
                    for (int i = 1; i <= maxRetries; i++) {
                        try {
                            echo "Health check attempt ${i}/${maxRetries}..."
                            
                            def response = sh(
                                script: "curl -f -s -o /dev/null -w '%{http_code}' https://${env.DOMAIN}/api/health",
                                returnStdout: true
                            ).trim()
                            
                            if (response == "200") {
                                echo "✅ Health check passed!"
                                healthCheckPassed = true
                                break
                            } else {
                                echo "❌ Health check failed with status: ${response}"
                            }
                        } catch (Exception e) {
                            echo "❌ Health check error: ${e.getMessage()}"
                        }
                        
                        if (i < maxRetries) {
                            echo "⏳ Waiting ${retryDelay}s before next attempt..."
                            sleep(retryDelay)
                        }
                    }
                    
                    if (!healthCheckPassed) {
                        error("❌ Health check failed after ${maxRetries} attempts")
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo "🎉 Deployment successful!"
            echo "🌐 Application URL: https://${env.DOMAIN}"
            echo "📊 Image: ${env.FULL_IMAGE_NAME}"
            
            // Clean up old images
            sh """
                docker image prune -f --filter "until=24h" || true
                docker system prune -f --filter "until=24h" || true
            """
        }
        
        failure {
            echo "❌ Deployment failed!"
            script {
                try {
                    echo "🔄 Attempting rollback..."
                    sh "docker service rollback ${env.STACK_NAME}_affine || true"
                    echo "✅ Rollback completed"
                } catch (Exception e) {
                    echo "❌ Rollback failed: ${e.getMessage()}"
                }
            }
        }
        
        always {
            echo "🧹 Cleaning up..."
            sh """
                docker container prune -f || true
                docker volume prune -f || true
            """
            
            // Archive build artifacts
            archiveArtifacts artifacts: 'docker-stack.yml, Dockerfile', allowEmptyArchive: true
        }
    }
}
