# Phase 11: EBS CSI 드라이버 - 순환 의존성 방지를 위해 별도 관리
# EKS 모듈의 cluster_addons에 포함 시 순환 의존성 발생
# 따라서 별도 aws_eks_addon 리소스로 관리

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"
  
  # Phase 11: EKS 클러스터, 노드 그룹, IRSA 모두 준비된 후 설치
  depends_on = [
    module.eks,
    module.eks.eks_managed_node_groups,
    module.ebs_csi_irsa,
  ]
  
  addon_version = null
  service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  # 타임아웃 설정 (Private Subnet 고려하여 연장)
  timeouts {
    create = "20m"
    update = "15m"
    delete = "10m"
  }
  
  tags = {
    Name        = "${var.ClusterBaseName}-ebs-csi-driver"
    Environment = "production"
    Purpose     = "EBS Volume Management"
  }
}

# Phase 10: EBS CSI 드라이버용 IRSA - 보안 강화를 위해 활성화
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"
  
  role_name = "${var.ClusterBaseName}-ebs-csi-driver"
  
  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
  
  attach_ebs_csi_policy = true
  
  # Phase 10: EKS 클러스터 OIDC 완료 후 생성
  depends_on = [
    module.eks,
  ]
  
  tags = {
    Name        = "${var.ClusterBaseName}-ebs-csi-driver-role"
    Environment = "production"
    Purpose     = "EBS Volume Management"
  }
}