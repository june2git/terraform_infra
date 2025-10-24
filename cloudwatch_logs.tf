# CloudWatch Log Group 보존 정책 설정
# EKS 클러스터 로깅 비용 최적화를 위한 보존 기간 설정

resource "aws_cloudwatch_log_group" "eks_api" {
  name              = "/aws/eks/${var.ClusterBaseName}/cluster/api"
  retention_in_days = var.api_log_retention_days
  
  tags = {
    Name        = "${var.ClusterBaseName}-eks-api-logs"
    Environment = "production"
    Purpose     = "EKS API server logs"
  }
}

resource "aws_cloudwatch_log_group" "eks_scheduler" {
  name              = "/aws/eks/${var.ClusterBaseName}/cluster/scheduler"
  retention_in_days = var.scheduler_log_retention_days
  
  tags = {
    Name        = "${var.ClusterBaseName}-eks-scheduler-logs"
    Environment = "production"
    Purpose     = "EKS scheduler logs"
  }
}

# 향후 필요시 추가 로그 그룹들을 위한 설정 (현재는 비활성화)
# resource "aws_cloudwatch_log_group" "eks_audit" {
#   name              = "/aws/eks/${var.ClusterBaseName}/cluster/audit"
#   retention_in_days = 7   # 7일 보존 (비용 절약)
#   
#   tags = {
#     Name        = "${var.ClusterBaseName}-eks-audit-logs"
#     Environment = "production"
#     Purpose     = "EKS audit logs"
#   }
# }

# resource "aws_cloudwatch_log_group" "eks_authenticator" {
#   name              = "/aws/eks/${var.ClusterBaseName}/cluster/authenticator"
#   retention_in_days = 7   # 7일 보존 (비용 절약)
#   
#   tags = {
#     Name        = "${var.ClusterBaseName}-eks-authenticator-logs"
#     Environment = "production"
#     Purpose     = "EKS authenticator logs"
#   }
# }

# resource "aws_cloudwatch_log_group" "eks_controller_manager" {
#   name              = "/aws/eks/${var.ClusterBaseName}/cluster/controllerManager"
#   retention_in_days = 7   # 7일 보존 (비용 절약)
#   
#   tags = {
#     Name        = "${var.ClusterBaseName}-eks-controller-logs"
#     Environment = "production"
#     Purpose     = "EKS controller manager logs"
#   }
# }
