// Failure Drill Pipeline - Observability Challenge
// This pipeline intentionally fails to test observability stack
// Use this to validate: metrics, logs, alerts, traces, and dashboards

pipeline {
    agent any
    
    parameters {
        choice(
            name: 'FAILURE_TYPE',
            choices: ['EXIT_CODE', 'TIMEOUT', 'TEST_FAILURE', 'RESOURCE_ERROR', 'FLAKY'],
            description: 'Type of failure to simulate'
        )
        
        choice(
            name: 'FAILURE_STAGE',
            choices: ['BUILD', 'TEST', 'DEPLOY'],
            description: 'Stage where failure should occur'
        )
        
        string(
            name: 'DELAY_SECONDS',
            defaultValue: '5',
            description: 'Seconds to wait before failure (to generate metrics)'
        )
    }
    
    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '50'))
    }
    
    environment {
        FAILURE_TYPE = "${params.FAILURE_TYPE}"
        FAILURE_STAGE = "${params.FAILURE_STAGE}"
        DRILL_ID = "DRILL-${BUILD_NUMBER}-${params.FAILURE_TYPE}"
    }
    
    stages {
        stage('🎯 Failure Drill Setup') {
            steps {
                script {
                    echo """
                    ╔═══════════════════════════════════════════╗
                    ║     FAILURE DRILL - OBSERVABILITY TEST     ║
                    ╚═══════════════════════════════════════════╝
                    
                    Drill ID: ${DRILL_ID}
                    Failure Type: ${FAILURE_TYPE}
                    Target Stage: ${FAILURE_STAGE}
                    Delay: ${params.DELAY_SECONDS}s
                    
                    This build will INTENTIONALLY FAIL for testing!
                    
                    📊 Monitor these systems:
                    - Prometheus metrics
                    - Grafana dashboards
                    - Alert firing
                    - Jaeger traces
                    - Jenkins logs
                    
                    Starting drill in 3 seconds...
                    """
                    sleep(3)
                }
            }
        }
        
        stage('✅ Healthy Stage 1') {
            steps {
                echo "Executing healthy stage 1..."
                sh '''
                    echo "Processing data..."
                    sleep 2
                    echo "Stage 1 completed successfully ✅"
                '''
            }
        }
        
        stage('✅ Healthy Stage 2') {
            steps {
                echo "Executing healthy stage 2..."
                sh '''
                    echo "Running preliminary checks..."
                    sleep 2
                    echo "Stage 2 completed successfully ✅"
                '''
            }
        }
        
        stage('🔨 Build Stage') {
            when {
                expression { params.FAILURE_STAGE == 'BUILD' }
            }
            steps {
                script {
                    echo "Build stage starting..."
                    sleep(params.DELAY_SECONDS.toInteger())
                    
                    echo "⚠️  INITIATING FAILURE DRILL: ${FAILURE_TYPE} ⚠️"
                    
                    switch(FAILURE_TYPE) {
                        case 'EXIT_CODE':
                            echo "Simulating command failure with bad exit code..."
                            sh '''
                                echo "Running build command..."
                                echo "ERROR: Build failed - compilation error on line 42"
                                exit 1
                            '''
                            break
                            
                        case 'TIMEOUT':
                            echo "Simulating timeout..."
                            timeout(time: 5, unit: 'SECONDS') {
                                sh '''
                                    echo "This command will timeout..."
                                    sleep 300
                                '''
                            }
                            break
                            
                        case 'RESOURCE_ERROR':
                            echo "Simulating resource error..."
                            sh '''
                                echo "ERROR: Out of memory during build"
                                echo "ERROR: Cannot allocate 8GB for compilation"
                                exit 137
                            '''
                            break
                            
                        default:
                            error("Unknown failure type: ${FAILURE_TYPE}")
                    }
                }
            }
        }
        
        stage('🧪 Test Stage') {
            when {
                expression { params.FAILURE_STAGE == 'TEST' }
            }
            steps {
                script {
                    echo "Test stage starting..."
                    
                    // Simulate some successful tests first
                    sh '''
                        echo "Running test suite..."
                        echo "✅ Test 1: PASSED"
                        echo "✅ Test 2: PASSED"
                        echo "✅ Test 3: PASSED"
                    '''
                    
                    sleep(params.DELAY_SECONDS.toInteger())
                    
                    echo "⚠️  INITIATING FAILURE DRILL: ${FAILURE_TYPE} ⚠️"
                    
                    switch(FAILURE_TYPE) {
                        case 'TEST_FAILURE':
                            echo "Simulating test failures..."
                            sh '''
                                echo "✅ Test 4: PASSED"
                                echo "❌ Test 5: FAILED - Expected 'true' but got 'false'"
                                echo "❌ Test 6: FAILED - NullPointerException at TestClass.java:156"
                                echo "✅ Test 7: PASSED"
                                echo "❌ Test 8: FAILED - Connection timeout"
                                echo ""
                                echo "Test Results: 5 passed, 3 failed"
                                exit 1
                            '''
                            break
                            
                        case 'FLAKY':
                            echo "Simulating flaky test..."
                            sh '''
                                # Randomly fail
                                RANDOM_NUM=$((RANDOM % 2))
                                if [ $RANDOM_NUM -eq 0 ]; then
                                    echo "❌ Test FAILED (flaky behavior detected)"
                                    exit 1
                                else
                                    echo "✅ Test PASSED"
                                fi
                            '''
                            break
                            
                        case 'EXIT_CODE':
                            sh 'exit 1'
                            break
                            
                        default:
                            error("Test stage failure: ${FAILURE_TYPE}")
                    }
                }
            }
        }
        
        stage('🚀 Deploy Stage') {
            when {
                expression { params.FAILURE_STAGE == 'DEPLOY' }
            }
            steps {
                script {
                    echo "Deploy stage starting..."
                    sleep(params.DELAY_SECONDS.toInteger())
                    
                    echo "⚠️  INITIATING FAILURE DRILL: ${FAILURE_TYPE} ⚠️"
                    
                    sh '''
                        echo "Connecting to deployment server..."
                        echo "ERROR: Connection refused - cannot reach deployment target"
                        echo "ERROR: Deployment failed"
                        exit 1
                    '''
                }
            }
        }
        
        stage('Should Not Reach') {
            steps {
                echo "❌ ERROR: This stage should never execute!"
                error("Pipeline did not fail as expected!")
            }
        }
    }
    
    post {
        always {
            script {
                def duration = currentBuild.durationString.replace(' and counting', '')
                echo """
                ╔═══════════════════════════════════════════╗
                ║        FAILURE DRILL COMPLETED             ║
                ╚═══════════════════════════════════════════╝
                
                Drill ID: ${DRILL_ID}
                Status: ${currentBuild.result}
                Duration: ${duration}
                
                📊 NOW CHECK YOUR OBSERVABILITY STACK:
                
                1. ✅ METRICS (Prometheus):
                   - jenkins_job_builds_failure_total should increase
                   - jenkins_job_last_build_result should show failure
                   Query: jenkins_job_builds_failure_total{jenkins_job="${JOB_NAME}"}
                
                2. ✅ DASHBOARDS (Grafana):
                   - "Failed Builds (5m)" panel should show +1
                   - Build duration graph should show the failed build
                   - Job status table should show red for this job
                
                3. ✅ ALERTS (Prometheus):
                   - "JenkinsBuildFailureSpike" alert should FIRE
                   Check: Prometheus → Alerts
                
                4. ✅ TRACES (Jaeger):
                   - Search for service: jenkins-ci
                   - Find trace for this build (#${BUILD_NUMBER})
                   - Verify spans show failure point
                
                5. ✅ LOGS (Jenkins Console):
                   - Console output shows failure details
                   - Error messages are clear
                   - Failure cause is identifiable
                
                ╔═══════════════════════════════════════════╗
                ║     COMPLETE YOUR BATTLE LOG NOW!         ║
                ╚═══════════════════════════════════════════╝
                """
            }
        }
        
        success {
            echo "⚠️  WARNING: Drill completed but did NOT fail (unexpected!)"
        }
        
        failure {
            echo "✅ EXPECTED: Pipeline failed as designed for drill"
            echo "This is a successful failure drill!"
        }
    }
}

