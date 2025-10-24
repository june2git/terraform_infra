##################
# Data Resources #
##################

# AWS 계정 정보 조회 (예: AWS Account ID)
data "aws_caller_identity" "current" {}



########################
# Security Group Setup #
########################

# 보안 그룹: EKS 워커 노드용 보안 그룹 생성
resource "aws_security_group" "node_group_sg" {
  name        = "${var.ClusterBaseName}-node-group-sg"
  description = "Security group for EKS Node Group"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.ClusterBaseName}-node-group-sg"
  }
}

# 보안 그룹 규칙: 특정 IP에서 EKS 워커 노드로 SSH(22번 포트) 접속 허용
resource "aws_security_group_rule" "allow_ssh" {
  type        = "ingress"
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["10.0.1.100/32"]

  security_group_id = aws_security_group.node_group_sg.id
}



#######################
# Amazon EKS Cluster  #
#######################

# EKS 모듈: 관리형 노드 그룹 및 기본 애드온이 포함된 EKS 클러스터 생성
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~>20.0"

  cluster_name = var.ClusterBaseName
  cluster_version = var.KubernetesVersion
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]
  
  # EKS 20.0+ 새로운 인증 방식 설정
  authentication_mode = "API_AND_CONFIG_MAP"
  
  # 실무 표준: 명시적인 액세스 엔트리 관리
  access_entries = {
    # DevOps 팀 관리자 액세스
    devops_admin = {
      principal_arn     = aws_iam_role.devops_admin.arn
      type              = "STANDARD"
      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            namespaces = []
            type       = "cluster"
          }
        }
      }
    }
    
    # 개발팀 제한된 액세스
    dev_team = {
      principal_arn     = aws_iam_role.dev_team.arn
      type              = "STANDARD"
      policy_associations = {
        dev_access = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
          access_scope = {
            namespaces = ["dev", "staging"]
            type       = "namespace"
          }
        }
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    # EBS CSI 드라이버 - IRSA를 통한 보안 강화
    aws-ebs-csi-driver = {
      most_recent = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
    # External-DNS는 별도 파일에서 관리
    # external-dns = {
    #   most_recent = true
    # }
  }

  vpc_id = module.vpc.vpc_id
  enable_irsa = true
  subnet_ids = module.vpc.private_subnets
  
  # 비용 최적화된 클러스터 로깅 설정
  cluster_enabled_log_types = [
    # "api",           # 필수: API 서버 로그
    # "scheduler"      # 저비용: 스케줄러 로그
    # audit, authenticator, controllerManager 제외 (비용 절약)
  ]
  
  # EKS 관리형 노드 그룹 설정
  eks_managed_node_groups = {
    default = {
      name             = "${var.ClusterBaseName}-node-group"
      use_name_prefix  = false
      instance_types   = ["${var.WorkerNodeInstanceType}"]
      desired_size     = var.WorkerNodeCount
      max_size         = var.WorkerNodeCount + 2
      min_size         = var.WorkerNodeCount - 1
      disk_size        = var.WorkerNodeVolumesize
      disk_type        = "gp3"
      subnets          = module.vpc.private_subnets
      key_name         = "kp_node"
      vpc_security_group_ids = [aws_security_group.node_group_sg.id]
      iam_role_name    = "${var.ClusterBaseName}-node-group-eks-node-group"
      iam_role_use_name_prefix = false
      
      # AL2023 최신 AMI 사용
      ami_type = "AL2023_x86_64_STANDARD"
      
      # 업데이트 설정
      update_config = {
        max_unavailable_percentage = 50
      }
      
      # 태그 설정
      tags = {
        Name = "${var.ClusterBaseName}-node-group"
        Environment = "production"
      }
   }
  }

  depends_on = [aws_instance.eks_bastion]

  tags = {
    Environment = "june2soul"
    Terraform   = "true"
  }
}

# EKS 20.0+에서는 aws-auth가 자동으로 관리됨
# 워커 노드 IAM Role은 EKS 모듈에서 자동으로 aws-auth에 추가됨





