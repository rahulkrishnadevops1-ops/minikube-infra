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
            sh 'chmod +x inventory.py'
            sh 'ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbook.yml --private-key "$ANSIBLE_KEY_FILE" -u ec2-user'
          }
        }
      }
    }

    stage('Setup API Tunnel') {
      when {
        expression { return !params.DESTROY }
      }
      steps {
        withCredentials([file(credentialsId: 'ssh-private-key', variable: 'ANSIBLE_KEY_FILE')]) {
          sh '''
            set -eu

            EC2_PUBLIC_IP="$(awk 'NR==2 {print $1}' infra/inventory.ini)"
            if [ -z "${EC2_PUBLIC_IP}" ]; then
              echo "Unable to resolve EC2 public IP from infra/inventory.ini"
              exit 1
            fi

            MINIKUBE_IP="$(ssh -i "$ANSIBLE_KEY_FILE" \
              -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              ec2-user@"${EC2_PUBLIC_IP}" "minikube ip")"
            if [ -z "${MINIKUBE_IP}" ]; then
              echo "Unable to resolve Minikube IP on remote host"
              exit 1
            fi

            if [ -f .minikube_tunnel_pid ]; then
              OLD_PID="$(cat .minikube_tunnel_pid || true)"
              if [ -n "${OLD_PID}" ] && kill -0 "${OLD_PID}" 2>/dev/null; then
                kill "${OLD_PID}" || true
                sleep 1
              fi
              rm -f .minikube_tunnel_pid
            fi

            nohup ssh -i "$ANSIBLE_KEY_FILE" \
              -o ExitOnForwardFailure=yes \
              -o ServerAliveInterval=30 \
              -o ServerAliveCountMax=3 \
              -o StrictHostKeyChecking=no \
              -o UserKnownHostsFile=/dev/null \
              -N -L 8443:${MINIKUBE_IP}:8443 ec2-user@"${EC2_PUBLIC_IP}" \
              > .minikube_tunnel.log 2>&1 &

            TUNNEL_PID="$!"
            echo "${TUNNEL_PID}" > .minikube_tunnel_pid
            echo "${EC2_PUBLIC_IP}" > .minikube_tunnel_host
            echo "${MINIKUBE_IP}" > .minikube_tunnel_minikube_ip
            sleep 3

            if ! kill -0 "${TUNNEL_PID}" 2>/dev/null; then
              echo "Tunnel process exited unexpectedly. Log output:"
              cat .minikube_tunnel.log || true
              exit 1
            fi

            curl -sk --max-time 10 https://127.0.0.1:8443/version >/dev/null
            echo "Tunnel ready: 127.0.0.1:8443 -> ${MINIKUBE_IP}:8443 via ${EC2_PUBLIC_IP}"
          '''
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
            sh 'chmod +x inventory.py'
            sh 'ANSIBLE_HOST_KEY_CHECKING=False ansible minikube -m shell -a "kubectl get nodes && helm version --short" --private-key "$ANSIBLE_KEY_FILE" -u ec2-user'
          }
        }
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'infra/inventory.ini', allowEmptyArchive: true
      archiveArtifacts artifacts: 'ansible/artifacts/*.yaml', allowEmptyArchive: true
      archiveArtifacts artifacts: '.minikube_tunnel*', allowEmptyArchive: true
    }
  }
}
