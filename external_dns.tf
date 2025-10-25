# Phase 9: External-DNS - 실무 표준 설정
# EKS 클러스터와 노드 그룹이 완전히 준비된 후 설치

resource "aws_eks_addon" "external_dns" {
  cluster_name = module.eks.cluster_name
  addon_name   = "external-dns"
  
  # Phase 9: 노드 그룹이 완전히 준비된 후 설치 (강화된 의존성)
  depends_on = [
    module.eks,
    module.eks.eks_managed_node_groups,
    module.external_dns_irsa,
  ]
  
  # 최신 버전 사용 (자동 선택)
  addon_version = null
  
  # 서비스 계정 역할 연결
  service_account_role_arn = module.external_dns_irsa.iam_role_arn
  
  # 충돌 해결 설정
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # 타임아웃 설정 (Private Subnet 고려하여 연장)
  timeouts {
    create = "20m"
    update = "15m"
    delete = "10m"
  }
  
  tags = {
    Name        = "${var.ClusterBaseName}-external-dns"
    Environment = "production"
    Purpose     = "DNS Management"
  }
}

# Phase 7: External-DNS용 IRSA
module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.ClusterBaseName}-external-dns"

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  attach_external_dns_policy = true

  # Phase 7: EKS 클러스터 OIDC 완료 후 생성
  depends_on = [
    module.eks,
  ]

  tags = {
    Name        = "${var.ClusterBaseName}-external-dns-role"
    Environment = "production"
    Purpose     = "DNS Management"
  }
}
