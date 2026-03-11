pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region for the EC2 instance')
    string(name: 'INSTANCE_TYPE', defaultValue: 'c7i.large', description: 'EC2 instance type')
    string(name: 'INSTANCE_NAME', defaultValue: 'minikube-control', description: 'Name tag for the EC2 instance')
    string(name: 'KEY_NAME', defaultValue: 'Ansible', description: 'Existing AWS EC2 key pair name')
    string(name: 'ALLOWED_SSH_CIDR', defaultValue: '0.0.0.0/0', description: 'CIDR block allowed to SSH to the instance')
    booleanParam(name: 'AUTO_APPLY', defaultValue: true, description: 'Apply Terraform automatically')
  }

  environment {
    TF_IN_AUTOMATION = 'true'
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Validate Inputs') {
      steps {
        script {
          if (!params.KEY_NAME?.trim()) {
            error('KEY_NAME is required.')
          }
        }
      }
    }

    stage('Terraform Init') {
      steps {
        dir('infra') {
          sh 'terraform init'
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        withCredentials([file(credentialsId: 'ec2-ssh-private-key', variable: 'SSH_KEY_FILE')]) {
          dir('infra') {
            script {
              def applyFlag = params.AUTO_APPLY ? '-auto-approve' : ''
              sh """
              terraform apply ${applyFlag} \
                -var "aws_region=${AWS_REGION}" \
                -var "instance_type=${INSTANCE_TYPE}" \
                -var "instance_name=${INSTANCE_NAME}" \
                -var "key_name=${KEY_NAME}" \
                -var "private_key_path=${SSH_KEY_FILE}" \
                -var "allowed_ssh_cidr=${ALLOWED_SSH_CIDR}"
              """
            }
          }
        }
      }
    }

    stage('Ansible Configure') {
      steps {
        dir('ansible') {
          sh 'ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbook.yml'
        }
      }
    }

    stage('Smoke Test') {
      steps {
        dir('ansible') {
          sh 'ansible minikube -m shell -a "kubectl get nodes && helm version --short"'
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'infra/inventory.ini', allowEmptyArchive: true
    }
  }
}
