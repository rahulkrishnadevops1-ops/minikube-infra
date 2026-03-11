pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
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

    stage('Terraform Init') {
      steps {
        dir('infra') {
          sh 'terraform init'
        }
      }
    }

    stage('Terraform Apply') {
      steps {
        dir('infra') {
          script {
            def applyFlag = params.AUTO_APPLY ? '-auto-approve' : ''
            sh "terraform apply ${applyFlag} -var-file=terraform.tfvars"
          }
        }
      }
    }

    stage('Ansible Configure') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'ANSIBLE_KEY_FILE', usernameVariable: 'ANSIBLE_USER')]) {
          dir('ansible') {
            sh 'ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbook.yml --private-key "$ANSIBLE_KEY_FILE" -u "$ANSIBLE_USER"'
          }
        }
      }
    }

    stage('Smoke Test') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'ANSIBLE_KEY_FILE', usernameVariable: 'ANSIBLE_USER')]) {
          dir('ansible') {
            sh 'ANSIBLE_HOST_KEY_CHECKING=False ansible minikube -m shell -a "kubectl get nodes && helm version --short" --private-key "$ANSIBLE_KEY_FILE" -u "$ANSIBLE_USER"'
          }
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
