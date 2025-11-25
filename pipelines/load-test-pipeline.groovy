// Load Test Pipeline - Generate Build Volume for Metrics
// Use this to generate multiple builds and test executor saturation

pipeline {
    agent any
    
    parameters {
        string(
            name: 'NUM_ITERATIONS',
            defaultValue: '10',
            description: 'Number of build iterations to run'
        )
        
        string(
            name: 'SLEEP_DURATION',
            defaultValue: '30',
            description: 'Seconds each iteration should take'
        )
        
        booleanParam(
            name: 'SIMULATE_SLOW_BUILD',
            defaultValue: false,
            description: 'Simulate slow build (>300s) to trigger alerts'
        )
    }
    
    options {
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }
    
    stages {
        stage('Load Test Execution') {
            steps {
                script {
                    def iterations = params.NUM_ITERATIONS.toInteger()
                    def sleepDuration = params.SLEEP_DURATION.toInteger()
                    
                    echo """
                    Starting Load Test
                    ==================
                    Iterations: ${iterations}
                    Duration per iteration: ${sleepDuration}s
                    Slow build simulation: ${params.SIMULATE_SLOW_BUILD}
                    """
                    
                    for (int i = 1; i <= iterations; i++) {
                        stage("Iteration ${i}/${iterations}") {
                            echo "Processing iteration ${i}..."
                            
                            if (params.SIMULATE_SLOW_BUILD && i == 3) {
                                echo "⚠️  Simulating SLOW BUILD (will exceed 300s threshold)"
                                sleep(350)  // Trigger slow build alert
                            } else {
                                sleep(sleepDuration)
                            }
                            
                            echo "Iteration ${i} completed ✅"
                        }
                    }
                    
                    echo """
                    Load Test Completed!
                    ====================
                    Total iterations: ${iterations}
                    
                    Check your dashboards:
                    - Total builds should show ${iterations} new builds
                    - Build duration metrics should be updated
                    - Executor utilization should show activity
                    """
                }
            }
        }
    }
    
    post {
        success {
            echo "✅ Load test completed successfully"
        }
    }
}

