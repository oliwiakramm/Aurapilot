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
                    docker run --rm aurapilot:ci-test python3 -m pytest tests/ -v --tb=short
                '''
            }
        }

        stage('Tag & Deploy') {
            steps {
                sh "docker tag aurapilot:ci-test aurapilot:${env.BUILD_NUMBER}"
                sh "docker tag aurapilot:ci-test aurapilot:latest"
                
                sh '''
                    docker compose up -d --force-recreate
                '''
            }
        }

        stage('Health check'){
            steps{
                retry(3){
                   sh '''
                        sleep 5
                        curl -sf http://localhost:8000/health || exit 1
                    '''
                }
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
            sh 'docker image prune -f'
        }
    }
}