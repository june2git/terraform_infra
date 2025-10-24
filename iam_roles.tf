# 실무용 EKS 액세스 IAM 역할들
# 보안과 권한 관리를 위한 명시적인 역할 정의

# DevOps 관리자 역할
resource "aws_iam_role" "devops_admin" {
  name = "${var.ClusterBaseName}-devops-admin-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.TargetRegion
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.ClusterBaseName}-devops-admin-role"
    Environment = "production"
    Purpose     = "EKS DevOps Admin Access"
  }
}

# 개발팀 역할
resource "aws_iam_role" "dev_team" {
  name = "${var.ClusterBaseName}-dev-team-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.TargetRegion
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.ClusterBaseName}-dev-team-role"
    Environment = "production"
    Purpose     = "EKS Dev Team Access"
  }
}

# DevOps 관리자 정책 연결
resource "aws_iam_role_policy_attachment" "devops_admin_eks_policy" {
  role       = aws_iam_role.devops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "devops_admin_eks_worker_policy" {
  role       = aws_iam_role.devops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "devops_admin_eks_cni_policy" {
  role       = aws_iam_role.devops_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# 개발팀 제한된 정책
resource "aws_iam_role_policy" "dev_team_limited" {
  name = "${var.ClusterBaseName}-dev-team-limited-policy"
  role = aws_iam_role.dev_team.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Resource = [
          "arn:aws:eks:${var.TargetRegion}:${data.aws_caller_identity.current.account_id}:cluster/${var.ClusterBaseName}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeNodegroup",
          "eks:ListNodegroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# 현재 AWS 계정 정보는 eks.tf에서 이미 선언됨
