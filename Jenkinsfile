pipeline{
    agent any
    stages{
        stage('Checkout'){
            steps{
                echo "Branch: ${env.GIT_BRANCH}"
                echo "Commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Build Image') {
            steps {
                sh '''
                    docker build -t aurapilot:ci-test .
                '''
            }
        }

        stage('Validate'){
            steps{
                sh '''
                    find . -name "*.json" -not -path "./.git/*" | xargs -I{} python3 -m json.tool {} > /dev/null
                '''
                
                sh '''
                    docker run --rm aurapilot:ci-test python3 -c "import yaml; yaml.safe_load(open('config/rules.yaml'))"
                '''
            }
        }
        stage('Tests'){
            steps{
               sh '''
                    docker run --rm aurapilot:ci-test python3 -m pytest tests/ -v --cov=app --tb=short
                '''
            }
        }

        stage('Tag & Deploy') {
            environment {
                GEMINI_API_KEY = credentials('GEMINI_API_KEY')
            }
            steps {
               sh "docker tag aurapilot:ci-test aurapilot:${env.BUILD_NUMBER}"
                sh "docker tag aurapilot:ci-test aurapilot:latest"
                
                sh 'docker rm -f aurapilot || true'
                
                sh 'docker network create aurapilot-net || true'
                
                sh '''
                    docker run -d \
                      --name aurapilot \
                      --network aurapilot-net \
                      -p 8000:8000 \
                      -e GEMINI_API_KEY="${GEMINI_API_KEY}" \
                      -v logs_data:/app/logs \
                      aurapilot:latest
                '''
            }
        }

        stage('Health check'){
            steps{
                retry(3){
                   sh '''
                        sleep 5
                        curl -sf http://aurapilot:8000/health || exit 1
                    '''
                }
            }

        }

        stage('BDD Tests (Robot)') {
            steps {
                sh '''
                    docker exec aurapilot python3 -m robot --outputdir logs/robot tests/bdd/
                '''
                sh 'docker cp aurapilot:/app/logs/robot ./logs/robot'
            }
        }
    }

    post{
        success {
            echo "Pipeline was successful. Aurapilot is running."
        }
        failure{
            echo "Pipeline failed — check logs above"
        }
        always {
            archiveArtifacts artifacts: 'logs/robot/*.html', allowEmptyArchive: true
            sh 'docker image prune -f'
        }
    }
}