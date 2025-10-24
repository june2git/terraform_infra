output "cluster_name" { 
  description = "EKS 클러스터 이름"
  value = module.eks.cluster_name 
}

output "cluster_endpoint" { 
  description = "EKS 클러스터 엔드포인트"
  value = module.eks.cluster_endpoint 
}

output "oidc_provider_arn" { 
  description = "EKS OIDC Provider ARN"
  value = module.eks.oidc_provider_arn 
}

output "ecr_repo_url" { 
  description = "ECR 저장소 URL"
  value = aws_ecr_repository.app.repository_url 
}

output "github_actions_role_arn" { 
  description = "GitHub Actions IAM 역할 ARN"
  value = aws_iam_role.github_actions.arn 
}

output "external_dns_role_arn" {
  description = "ExternalDNS IAM 역할 ARN"
  value = module.external_dns_irsa.iam_role_arn
}

output "bastion_public_ip" {
  description = "Bastion Host Public IP 주소"
  value = aws_instance.eks_bastion.public_ip
}

output "bastion_private_ip" {
  description = "Bastion Host Private IP 주소"
  value = aws_instance.eks_bastion.private_ip
}

output "bastion_ssh_command" {
  description = "Bastion Host SSH 접속 명령어"
  value = "ssh -i ${var.KeyName}.pem ubuntu@${aws_instance.eks_bastion.public_ip}"
}

output "bastion_key_name" {
  description = "Bastion Host SSH Key 이름"
  value = var.KeyName
}

output "vpc_id" {
  description = "VPC ID"
  value = module.vpc.vpc_id
}

output "public_subnets" {
  description = "퍼블릭 서브넷 ID 목록"
  value = module.vpc.public_subnets
}

output "private_subnets" {
  description = "프라이빗 서브넷 ID 목록"
  value = module.vpc.private_subnets
}

output "cloudwatch_log_groups" {
  description = "CloudWatch Log Groups 정보"
  value = {
    api_log_group      = aws_cloudwatch_log_group.eks_api.name
    scheduler_log_group = aws_cloudwatch_log_group.eks_scheduler.name
    api_retention_days  = aws_cloudwatch_log_group.eks_api.retention_in_days
    scheduler_retention_days = aws_cloudwatch_log_group.eks_scheduler.retention_in_days
  }
}

output "eks_access_roles" {
  description = "EKS 액세스 IAM 역할 정보"
  value = {
    devops_admin_role_arn = aws_iam_role.devops_admin.arn
    dev_team_role_arn     = aws_iam_role.dev_team.arn
    devops_admin_role_name = aws_iam_role.devops_admin.name
    dev_team_role_name     = aws_iam_role.dev_team.name
  }
}

output "eks_access_instructions" {
  description = "EKS 클러스터 액세스 방법"
  value = {
    devops_admin_access = "aws eks update-kubeconfig --region ${var.TargetRegion} --name ${var.ClusterBaseName} --role-arn ${aws_iam_role.devops_admin.arn}"
    dev_team_access     = "aws eks update-kubeconfig --region ${var.TargetRegion} --name ${var.ClusterBaseName} --role-arn ${aws_iam_role.dev_team.arn}"
    cluster_endpoint    = module.eks.cluster_endpoint
  }
}
