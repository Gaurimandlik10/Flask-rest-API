pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
        AWS_DEFAULT_REGION    = 'ap-southeast-2'
        AWS_ACCOUNT_ID        = '500345929326'
        ECR_REPO              = "devops_projects"
        IMAGE_TAG             = "build-${env.BUILD_NUMBER}"
        ECR_URL               = "${AWS_ACCOUNT_ID}.dkr.ecr.ap-southeast-2.amazonaws.com"
    }

    stages {
        stage('Building Docker Image') {
            steps {
                echo "Building Docker Image..."
                sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} -f app/Dockerfile app"
            }
        }
        
        stage('Pushing to ECR') {
            steps {
                echo "Pushing to ECR..."
                sh """
                    aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_URL}
                    docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}
                    docker push ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG}
                """
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([string(credentialsId: 'prod-db-password', variable: 'TF_VAR_db_password')]) {
                    sh """
                        cd terraform
                        terraform init
                        terraform apply -auto-approve
                    """
                }
            }
        }
          stage('Configure Kubeconfig') {
            steps {
                echo "Updating kubeconfig for EKS access..."
                sh "aws eks update-kubeconfig --name flask-postgres-cluster --region ${AWS_DEFAULT_REGION}"
            }
        }
 
        stage('Deploy to Staging') {
            steps {
                withCredentials([string(credentialsId: 'staging-db-password', variable: 'DB_PASSWORD')]) {
                    sh(script: '''
                        helm upgrade --install flask-staging ./helm/flask-chart \
                            -f ./helm/flask-chart/values.yaml \
                            -f ./helm/flask-chart/values-staging.yaml \
                            -n staging --create-namespace \
                            --set image.repository=$IMAGE_REPO \
                            --set image.tag=$IMAGE_TAG \
                            --set db.password=$DB_PASSWORD
                    ''')
                }
            }
        }

        stage('Verify Staging') {
            steps {
                sh """
                    kubectl rollout status deployment/flask-staging-flaskrestapi -n staging --timeout=300s
                    kubectl get pods -n staging
                """
            }
        }

        stage('Approve Prod Deploy') {
            steps {
                input message: 'Staging looks good. Deploy to PRODUCTION?', ok: 'Yes, Deploy'
            }
        }

        stage('Deploy to Prod') {
            steps {
                withCredentials([string(credentialsId: 'prod-db-password', variable: 'DB_PASSWORD')]) {
                    script {
                        def rdsEndpoint = sh(script: "terraform -chdir=terraform output -raw rds_endpoint", returnStdout: true).trim()
                        sh """
                            docker tag ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG} ${ECR_URL}/${ECR_REPO}:prod-latest
                            docker push ${ECR_URL}/${ECR_REPO}:prod-latest

                            helm upgrade --install flask-prod ./helm/flask-chart \
                                -f ./helm/flask-chart/values.yaml \
                                -f ./helm/flask-chart/values-prod.yaml \
                                -n prod --create-namespace \
                                --set image.repository=${ECR_URL}/${ECR_REPO} \
                                --set image.tag=${IMAGE_TAG} \
                                --set db.password=${DB_PASSWORD} \
                                --set db.host=${rdsEndpoint}
                        """
                    }
                }
            }
        }

        stage('Verify Prod') {
            steps {
                sh """
                    kubectl rollout status deployment/flask-prod-flaskrestapi -n prod --timeout=300s
                    kubectl get pods -n prod
                """
            }
        }
    }

    post {
        success {
            echo "Pipeline completed. Flask API deployed successfully."
        }
        failure {
            echo "Pipeline failed. Check logs above."
        }
        always {
            sh "docker rmi ${ECR_REPO}:${IMAGE_TAG} ${ECR_URL}/${ECR_REPO}:${IMAGE_TAG} || true"
        }
    }
}
