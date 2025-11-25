// Queue Test Pipeline - Test Jenkins Queue Backlog Alert
// This pipeline can be triggered multiple times to test queue behavior

pipeline {
    agent any
    
    parameters {
        string(
            name: 'EXECUTION_TIME',
            defaultValue: '120',
            description: 'Seconds this build should run (to occupy executor)'
        )
    }
    
    options {
        timeout(time: 10, unit: 'MINUTES')
        timestamps()
        // Allow concurrent builds to fill the queue
        // disableConcurrentBuilds()
    }
    
    stages {
        stage('Occupy Executor') {
            steps {
                script {
                    def execTime = params.EXECUTION_TIME.toInteger()
                    
                    echo """
                    Queue Test Pipeline
                    ===================
                    Build: #${BUILD_NUMBER}
                    Execution time: ${execTime}s
                    
                    This build will occupy an executor for testing queue behavior.
                    
                    To test queue backlog alert:
                    1. Trigger this pipeline 10+ times
                    2. Monitor jenkins_queue_size metric
                    3. Alert should fire when queue > 5
                    """
                    
                    echo "Occupying executor..."
                    sleep(execTime)
                    
                    echo "Releasing executor ✅"
                }
            }
        }
    }
    
    post {
        always {
            echo """
            Build #${BUILD_NUMBER} completed
            
            Check metrics:
            - jenkins_queue_size
            - jenkins_executor_busy
            - jenkins_queue_waiting
            """
        }
    }
}

