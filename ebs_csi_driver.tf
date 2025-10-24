# EBS CSI 드라이버 - EKS 모듈에서 직접 관리로 변경
# 타임아웃 문제 해결을 위해 EKS 모듈에서 직접 관리

# 별도 파일에서 관리하던 EBS-CSI 드라이버를 EKS 모듈로 이동
# 이제 eks.tf의 cluster_addons에서 직접 관리됨

# 필요시 아래 주석을 해제하여 별도 관리 가능
# resource "aws_eks_addon" "ebs_csi_driver" {
#   cluster_name = module.eks.cluster_name
#   addon_name   = "aws-ebs-csi-driver"
#   depends_on = [
#     module.eks,
#     module.eks.eks_managed_node_groups,
#     module.ebs_csi_irsa,
#     aws_instance.eks_bastion
#   ]
#   addon_version = null
#   service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"
#   timeouts {
#     create = "20m"
#     update = "15m"
#     delete = "10m"
#   }
#   tags = {
#     Name        = "${var.ClusterBaseName}-ebs-csi-driver"
#     Environment = "production"
#     Purpose     = "EBS Volume Management"
#   }
# }

# EBS CSI 드라이버용 IRSA - 보안 강화를 위해 활성화
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
  
  tags = {
    Name        = "${var.ClusterBaseName}-ebs-csi-driver-role"
    Environment = "production"
    Purpose     = "EBS Volume Management"
  }
}