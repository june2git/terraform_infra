data "aws_ssm_parameter" "ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_security_group" "bastion_sg" {
  name_prefix = "${var.ClusterBaseName}-bastion-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for Bastion Host (Jump Server)"

  ingress {
    description = "SSH access from specified IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.SgIngressSshCidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.ClusterBaseName}-bastion-sg"
  }
}

resource "aws_instance" "eks_bastion" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = var.MyInstanceType
  key_name                    = var.KeyName
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  private_ip                  = "10.0.1.100"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  tags = {
    Name = "${var.ClusterBaseName}-bastion-ec2"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 30
    delete_on_termination = true
  }

  user_data = <<-EOF
    #!/bin/bash
    set -e
    
    hostnamectl --static set-hostname "${var.ClusterBaseName}-bastion-EC2"
    timedatectl set-timezone Asia/Seoul
    
    echo 'alias vi=vim' >> /etc/profile
    echo "sudo su -" >> /home/ubuntu/.bashrc

    apt update
    apt install -y tree jq git htop unzip curl wget

    curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2024-12-20/bin/linux/amd64/kubectl
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    
    curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    
    curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip >/dev/null 2>&1
    ./aws/install
    rm -rf awscliv2.zip aws/
    
    complete -C '/usr/local/bin/aws_completer' aws
    echo 'export AWS_PAGER=""' >> /etc/profile
    echo "export AWS_DEFAULT_REGION=${var.TargetRegion}" >> /etc/profile

    wget -q https://github.com/andreazorzetto/yh/releases/download/v0.4.0/yh-linux-amd64.zip
    unzip -q yh-linux-amd64.zip
    mv yh /usr/local/bin/
    rm yh-linux-amd64.zip

    git clone https://github.com/ahmetb/kubectx /opt/kubectx >/dev/null 2>&1
    ln -s /opt/kubectx/kubens /usr/local/bin/kubens
    ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    rm get-docker.sh

    echo 'source <(kubectl completion bash)' >> /root/.bashrc
    echo 'alias k=kubectl' >> /root/.bashrc
    echo 'complete -F __start_kubectl k' >> /root/.bashrc

    git clone https://github.com/jonmosco/kube-ps1.git /root/kube-ps1
    cat <<"EOT" >> /root/.bashrc
    source /root/kube-ps1/kube-ps1.sh
    KUBE_PS1_SYMBOL_ENABLE=false
    function get_cluster_short() {
      echo "$1" | grep -o '${var.ClusterBaseName}[^/]*' | cut -c 1-13 
    }
    KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
    KUBE_PS1_SUFFIX=') '
    PS1='$(kube_ps1)'$PS1
    EOT

    export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
    echo "export ACCOUNT_ID=$ACCOUNT_ID" >> /etc/profile
    
    if [ -n "${var.MyIamUserAccessKeyID}" ] && [ -n "${var.MyIamUserSecretAccessKey}" ]; then
      export AWS_ACCESS_KEY_ID="${var.MyIamUserAccessKeyID}"
      export AWS_SECRET_ACCESS_KEY="${var.MyIamUserSecretAccessKey}"
      echo "export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID" >> /etc/profile
      echo "export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY" >> /etc/profile
    fi

    export CLUSTER_NAME="${var.ClusterBaseName}"
    echo "export CLUSTER_NAME=$CLUSTER_NAME" >> /etc/profile

    export VPCID="${module.vpc.vpc_id}"
    echo "export VPCID=$VPCID" >> /etc/profile
    
    export PublicSubnet1="${module.vpc.public_subnets[0]}"
    export PublicSubnet2="${module.vpc.public_subnets[1]}"
    export PrivateSubnet1="${module.vpc.private_subnets[0]}"
    export PrivateSubnet2="${module.vpc.private_subnets[1]}"
    
    echo "export PublicSubnet1=$PublicSubnet1" >> /etc/profile
    echo "export PublicSubnet2=$PublicSubnet2" >> /etc/profile
    echo "export PrivateSubnet1=$PrivateSubnet1" >> /etc/profile
    echo "export PrivateSubnet2=$PrivateSubnet2" >> /etc/profile

    aws eks update-kubeconfig --region ${var.TargetRegion} --name $CLUSTER_NAME

    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
    
    echo "Host worker-*" >> /root/.ssh/config
    echo "  User ec2-user" >> /root/.ssh/config
    echo "  IdentityFile /root/.ssh/id_rsa" >> /root/.ssh/config
    echo "  StrictHostKeyChecking no" >> /root/.ssh/config
    echo "  UserKnownHostsFile /dev/null" >> /root/.ssh/config
    
    cat << 'EOT' > /usr/local/bin/get-worker-ips
#!/bin/bash
echo "=== EKS 워커 노드 IP 주소 ==="
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" \
           "Name=instance-state-name,Values=running" \
           "Name=tag:kubernetes.io/role/node,Values=1" \
  --query 'Reservations[*].Instances[*].[PrivateIpAddress,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
EOT
    chmod +x /usr/local/bin/get-worker-ips
    
    cat << 'EOT' > /usr/local/bin/ssh-worker
#!/bin/bash
if [ $# -eq 0 ]; then
  echo "사용법: ssh-worker <노드번호>"
  echo "예시: ssh-worker 1"
  exit 1
fi

NODE_NUM=$1
WORKER_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" \
           "Name=instance-state-name,Values=running" \
           "Name=tag:kubernetes.io/role/node,Values=1" \
  --query "Reservations[*].Instances[$((NODE_NUM-1))].PrivateIpAddress" \
  --output text)

if [ "$WORKER_IP" = "None" ] || [ -z "$WORKER_IP" ]; then
  echo "워커 노드 $NODE_NUM을 찾을 수 없습니다."
  exit 1
fi

echo "워커 노드 $NODE_NUM ($WORKER_IP)에 접속합니다..."
ssh ec2-user@$WORKER_IP
EOT
    chmod +x /usr/local/bin/ssh-worker
    
    echo "=========================================="
    echo "Bastion Host 설정 완료!"
    echo "클러스터: $CLUSTER_NAME"
    echo "VPC ID: $VPCID"
    echo ""
    echo "워커 노드 접속 명령어:"
    echo "  get-worker-ips  # 워커 노드 IP 조회"
    echo "  ssh-worker 1    # 첫 번째 워커 노드 접속"
    echo "  ssh-worker 2    # 두 번째 워커 노드 접속"
    echo "=========================================="

  EOF
  
  user_data_replace_on_change = true
  
}
