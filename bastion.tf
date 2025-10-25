# Phase 2: Bastion Host 설정
# Jump Server 역할을 하는 EC2 인스턴스

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# Phase 2: Bastion Host 보안 그룹
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

# Phase 5: Bastion에서 EKS Cluster API 서버로 접근 허용
# EKS 클러스터 생성 후에 보안 그룹 규칙 추가
resource "aws_security_group_rule" "bastion_to_eks_api" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.bastion_sg.id
  security_group_id        = module.eks.cluster_security_group_id
  description              = "Allow Bastion to access EKS API server"
  
  # Phase 5: EKS 클러스터 생성 후 규칙 추가
  depends_on = [
    module.eks,
  ]
}

# Phase 2: Bastion Host EC2 인스턴스
resource "aws_instance" "eks_bastion" {
  ami                         = data.aws_ssm_parameter.ami.value
  instance_type               = var.MyInstanceType
  key_name                    = var.KeyName
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  private_ip                  = "10.0.1.100"
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]

  # Phase 2: VPC 완료 후 생성
  depends_on = [
    module.vpc,
  ]

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
    
    # 로그 파일 설정
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "=========================================="
    echo "Bastion Host 초기화 시작: $(date)"
    echo "=========================================="
    
    # 기본 설정
    hostnamectl --static set-hostname "${var.ClusterBaseName}-bastion-EC2"
    timedatectl set-timezone Asia/Seoul
    
    echo 'alias vi=vim' >> /etc/profile
    echo "sudo su -" >> /home/ubuntu/.bashrc

    # 패키지 업데이트 및 기본 도구 설치
    echo "[1/10] 패키지 업데이트 및 기본 도구 설치 중..."
    apt update -y
    apt install -y tree jq git htop unzip curl wget

    # kubectl 설치
    echo "[2/10] kubectl 설치 중..."
    curl -LO https://s3.us-west-2.amazonaws.com/amazon-eks/1.33.0/2024-12-20/bin/linux/amd64/kubectl
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Helm 설치
    echo "[3/10] Helm 설치 중..."
    curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    
    # eksctl 설치
    echo "[4/10] eksctl 설치 중..."
    curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin

    # AWS CLI v2 설치
    echo "[5/10] AWS CLI v2 설치 중..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/
    
    complete -C '/usr/local/bin/aws_completer' aws
    echo 'export AWS_PAGER=""' >> /etc/profile
    echo "export AWS_DEFAULT_REGION=${var.TargetRegion}" >> /etc/profile

    # yh (YAML Highlighter) 설치
    echo "[6/10] yh 설치 중..."
    wget -q https://github.com/andreazorzetto/yh/releases/download/v0.4.0/yh-linux-amd64.zip
    unzip -q yh-linux-amd64.zip
    mv yh /usr/local/bin/
    rm yh-linux-amd64.zip

    # kubectx/kubens 설치
    echo "[7/10] kubectx/kubens 설치 중..."
    git clone -q https://github.com/ahmetb/kubectx /opt/kubectx
    ln -s /opt/kubectx/kubens /usr/local/bin/kubens
    ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx

    # Docker 설치
    echo "[8/10] Docker 설치 중..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    rm get-docker.sh

    # kubectl 자동완성 및 별칭 설정
    echo 'source <(kubectl completion bash)' >> /root/.bashrc
    echo 'alias k=kubectl' >> /root/.bashrc
    echo 'complete -F __start_kubectl k' >> /root/.bashrc

    # kube-ps1 설치
    echo "[9/10] kube-ps1 설치 중..."
    git clone -q https://github.com/jonmosco/kube-ps1.git /root/kube-ps1
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

    # AWS 자격 증명 설정
    echo "[10/10] AWS 환경 변수 설정 중..."
    if [ -n "${var.MyIamUserAccessKeyID}" ] && [ -n "${var.MyIamUserSecretAccessKey}" ]; then
      export AWS_ACCESS_KEY_ID="${var.MyIamUserAccessKeyID}"
      export AWS_SECRET_ACCESS_KEY="${var.MyIamUserSecretAccessKey}"
      echo "export AWS_ACCESS_KEY_ID='${var.MyIamUserAccessKeyID}'" >> /etc/profile
      echo "export AWS_SECRET_ACCESS_KEY='${var.MyIamUserSecretAccessKey}'" >> /etc/profile
      
      # ACCOUNT_ID 가져오기 (자격 증명 설정 후)
      export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text 2>/dev/null || echo "unknown")
      echo "export ACCOUNT_ID='$ACCOUNT_ID'" >> /etc/profile
    fi

    # 클러스터 정보 환경 변수 설정
    export CLUSTER_NAME="${var.ClusterBaseName}"
    echo "export CLUSTER_NAME='$CLUSTER_NAME'" >> /etc/profile

    export VPCID="${module.vpc.vpc_id}"
    echo "export VPCID='$VPCID'" >> /etc/profile
    
    export PublicSubnet1="${module.vpc.public_subnets[0]}"
    export PublicSubnet2="${module.vpc.public_subnets[1]}"
    export PrivateSubnet1="${module.vpc.private_subnets[0]}"
    export PrivateSubnet2="${module.vpc.private_subnets[1]}"
    
    echo "export PublicSubnet1='$PublicSubnet1'" >> /etc/profile
    echo "export PublicSubnet2='$PublicSubnet2'" >> /etc/profile
    echo "export PrivateSubnet1='$PrivateSubnet1'" >> /etc/profile
    echo "export PrivateSubnet2='$PrivateSubnet2'" >> /etc/profile

    # kubeconfig 설정 (재시도 로직)
    echo "kubeconfig 설정 중..."
    for i in {1..5}; do
      if aws eks update-kubeconfig --region ${var.TargetRegion} --name $CLUSTER_NAME 2>/dev/null; then
        echo "✓ kubeconfig 설정 성공!"
        break
      else
        echo "⚠ kubeconfig 설정 실패 (시도 $i/5), 30초 후 재시도..."
        sleep 30
      fi
    done

    # SSH 키 생성 및 설정
    ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
    
    cat >> /root/.ssh/config <<SSHEOF
Host worker-*
  User ec2-user
  IdentityFile /root/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
SSHEOF
    
    # 워커 노드 관리 스크립트 생성
    cat > /usr/local/bin/get-worker-ips <<'SCRIPTEOF'
#!/bin/bash
echo "=== EKS 워커 노드 IP 주소 ==="
aws ec2 describe-instances \
  --filters "Name=tag:kubernetes.io/cluster/$CLUSTER_NAME,Values=owned" \
           "Name=instance-state-name,Values=running" \
           "Name=tag:kubernetes.io/role/node,Values=1" \
  --query 'Reservations[*].Instances[*].[PrivateIpAddress,PublicIpAddress,Tags[?Key==`Name`].Value|[0]]' \
  --output table
SCRIPTEOF
    chmod +x /usr/local/bin/get-worker-ips
    
    cat > /usr/local/bin/ssh-worker <<'SCRIPTEOF'
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
SCRIPTEOF
    chmod +x /usr/local/bin/ssh-worker
    
    echo "=========================================="
    echo "Bastion Host 설정 완료! $(date)"
    echo "클러스터: $CLUSTER_NAME"
    echo "VPC ID: $VPCID"
    echo "계정 ID: $ACCOUNT_ID"
    echo ""
    echo "설치된 도구:"
    echo "  - kubectl: $(kubectl version --client --short 2>/dev/null || echo 'installed')"
    echo "  - aws-cli: $(aws --version 2>/dev/null || echo 'installed')"
    echo "  - helm: $(helm version --short 2>/dev/null || echo 'installed')"
    echo "  - docker: $(docker --version 2>/dev/null || echo 'installed')"
    echo ""
    echo "워커 노드 접속 명령어:"
    echo "  get-worker-ips  # 워커 노드 IP 조회"
    echo "  ssh-worker 1    # 첫 번째 워커 노드 접속"
    echo "  ssh-worker 2    # 두 번째 워커 노드 접속"
    echo ""
    echo "로그 확인: sudo cat /var/log/user-data.log"
    echo "=========================================="

  EOF
  
  user_data_replace_on_change = true
  
}
