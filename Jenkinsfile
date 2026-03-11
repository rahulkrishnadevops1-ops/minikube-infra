pipeline {
  agent any

  options {
    timestamps()
  }

  parameters {
    booleanParam(name: 'AUTO_APPLY', defaultValue: true, description: 'Apply Terraform automatically')
    booleanParam(name: 'DESTROY', defaultValue: false, description: 'Destroy infrastructure instead of apply')
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
      when {
        expression { return !params.DESTROY }
      }
      steps {
        dir('infra') {
          script {
            def applyFlag = params.AUTO_APPLY ? '-auto-approve' : ''
            sh "terraform apply ${applyFlag} -var-file=terraform.tfvars"
          }
        }
      }
    }

    stage('Terraform Destroy') {
      when {
        expression { return params.DESTROY }
      }
      steps {
        dir('infra') {
          sh 'terraform destroy -auto-approve -var-file=terraform.tfvars'
        }
      }
    }

    stage('Ansible Configure') {
      when {
        expression { return !params.DESTROY }
      }
      steps {
        withCredentials([file(credentialsId: 'ssh-private-key', variable: 'ANSIBLE_KEY_FILE')]) {
          dir('ansible') {
            sh 'ANSIBLE_CONFIG=ansible.cfg ANSIBLE_INVENTORY_ENABLED=amazon.aws.aws_ec2 ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i aws_ec2.yaml playbook.yml --private-key "$ANSIBLE_KEY_FILE" -u ec2-user'
          }
        }
      }
    }

    stage('Smoke Test') {
      when {
        expression { return !params.DESTROY }
      }
      steps {
        withCredentials([file(credentialsId: 'ssh-private-key', variable: 'ANSIBLE_KEY_FILE')]) {
          dir('ansible') {
            sh 'ANSIBLE_CONFIG=ansible.cfg ANSIBLE_INVENTORY_ENABLED=amazon.aws.aws_ec2 ANSIBLE_HOST_KEY_CHECKING=False ansible -i aws_ec2.yaml minikube -m shell -a "kubectl get nodes && helm version --short" --private-key "$ANSIBLE_KEY_FILE" -u ec2-user'
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
