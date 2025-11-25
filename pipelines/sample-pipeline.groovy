// Sample Jenkins Pipeline with OpenTelemetry Tracing
// This pipeline demonstrates various stages that will be traced

pipeline {
    agent any
    
    options {
        // Set build timeout
        timeout(time: 30, unit: 'MINUTES')
        
        // Keep only last 10 builds
        buildDiscarder(logRotator(numToKeepStr: '10'))
        
        // Disable concurrent builds
        disableConcurrentBuilds()
        
        // Timestamps in console
        timestamps()
    }
    
    environment {
        // Environment variables
        APP_NAME = 'sample-app'
        APP_VERSION = '1.0.0'
        BUILD_TIMESTAMP = sh(script: "date +%Y%m%d-%H%M%S", returnStdout: true).trim()
    }
    
    stages {
        stage('📋 Environment Setup') {
            steps {
                echo "==================================="
                echo "Starting Build for ${APP_NAME}"
                echo "Version: ${APP_VERSION}"
                echo "Build: #${BUILD_NUMBER}"
                echo "Timestamp: ${BUILD_TIMESTAMP}"
                echo "==================================="
                
                // Add custom OTel attributes
                script {
                    // These will appear in traces
                    env.TRACE_ID = UUID.randomUUID().toString()
                    echo "Trace ID: ${env.TRACE_ID}"
                }
            }
        }
        
        stage('🔍 SCM Checkout') {
            steps {
                echo "Checking out source code..."
                
                // Simulate git checkout (replace with actual git step in real scenario)
                script {
                    // In real pipeline, use: checkout scm
                    sh '''
                        echo "Simulating git clone..."
                        sleep 2
                        echo "Git checkout completed"
                    '''
                }
            }
        }
        
        stage('🔧 Build') {
            steps {
                echo "Building application..."
                
                script {
                    // Simulate build process
                    sh '''
                        echo "Installing dependencies..."
                        sleep 3
                        
                        echo "Compiling code..."
                        sleep 5
                        
                        echo "Creating artifacts..."
                        mkdir -p build/
                        echo "Build artifact ${BUILD_NUMBER}" > build/app-${BUILD_NUMBER}.jar
                        
                        echo "Build completed successfully!"
                    '''
                }
            }
        }
        
        stage('🧪 Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        echo "Running unit tests..."
                        sh '''
                            echo "Executing unit test suite..."
                            sleep 4
                            echo "✅ Unit tests passed: 150/150"
                        '''
                    }
                }
                
                stage('Integration Tests') {
                    steps {
                        echo "Running integration tests..."
                        sh '''
                            echo "Executing integration test suite..."
                            sleep 6
                            echo "✅ Integration tests passed: 45/45"
                        '''
                    }
                }
                
                stage('Code Quality') {
                    steps {
                        echo "Running code quality checks..."
                        sh '''
                            echo "Running linter..."
                            sleep 2
                            
                            echo "Running static analysis..."
                            sleep 3
                            
                            echo "✅ Code quality checks passed"
                        '''
                    }
                }
            }
        }
        
        stage('📦 Package') {
            steps {
                echo "Packaging application..."
                
                sh '''
                    echo "Creating distribution package..."
                    tar -czf build/app-${BUILD_NUMBER}.tar.gz build/app-${BUILD_NUMBER}.jar
                    
                    echo "Package created: app-${BUILD_NUMBER}.tar.gz"
                    ls -lh build/
                '''
            }
        }
        
        stage('📤 Archive Artifacts') {
            steps {
                echo "Archiving build artifacts..."
                
                // Archive artifacts
                script {
                    sh '''
                        echo "Uploading artifacts to artifact repository..."
                        sleep 2
                        echo "✅ Artifacts archived successfully"
                    '''
                }
            }
        }
        
        stage('🚀 Deploy to Staging') {
            when {
                branch 'main'
            }
            steps {
                echo "Deploying to staging environment..."
                
                sh '''
                    echo "Connecting to staging server..."
                    sleep 2
                    
                    echo "Deploying application..."
                    sleep 4
                    
                    echo "Running smoke tests..."
                    sleep 3
                    
                    echo "✅ Deployment to staging successful!"
                '''
            }
        }
    }
    
    post {
        always {
            echo "==================================="
            echo "Build ${currentBuild.result ?: 'SUCCESS'}"
            echo "Duration: ${currentBuild.durationString}"
            echo "==================================="
            
            // Clean up workspace
            cleanWs()
        }
        
        success {
            echo "✅ Pipeline completed successfully!"
            
            // In real scenario, send notifications
            script {
                echo "Sending success notification..."
            }
        }
        
        failure {
            echo "❌ Pipeline failed!"
            
            // In real scenario, send failure notifications
            script {
                echo "Sending failure notification..."
            }
        }
        
        unstable {
            echo "⚠️  Pipeline is unstable!"
        }
    }
}

