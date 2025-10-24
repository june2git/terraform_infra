# Kubernetes 리소스는 Bastion Host에서 수동으로 설치 필요
# 로컬에서는 EKS 클러스터에 대한 kubectl 접근 권한이 없음

# resource "kubernetes_service_account" "alb" {
#   metadata {
#     name      = "aws-load-balancer-controller"
#     namespace = "kube-system"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = module.alb_irsa.iam_role_arn
#     }
#   }
# }

# resource "helm_release" "alb_controller" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"
#   version    = "1.8.2"
# 
#   depends_on = [
#     module.eks,
#     kubernetes_service_account.alb
#   ]
# 
#   set = [
#     {
#       name  = "clusterName"
#       value = module.eks.cluster_name
#     },
#     {
#       name  = "serviceAccount.create"
#       value = "false"
#     },
#     {
#       name  = "serviceAccount.name"
#       value = "aws-load-balancer-controller"
#     },
#     {
#       name  = "region"
#       value = var.TargetRegion
#     },
#     {
#       name  = "vpcId"
#       value = module.vpc.vpc_id
#     }
#   ]
# }

# resource "kubernetes_namespace" "argocd" {
#   metadata {
#     name = "argocd"
#   }
# }

# resource "helm_release" "argocd" {
#   name       = "argo-cd"
#   repository = "https://argoproj.github.io/argo-helm"
#   chart      = "argo-cd"
#   namespace  = kubernetes_namespace.argocd.metadata[0].name
#   version    = "7.6.12"
# 
#   depends_on = [module.eks]
# 
#   set = [
#     {
#       name  = "configs.params.server.insecure"
#       value = "true"
#     },
#     {
#       name  = "server.service.type"
#       value = "LoadBalancer"
#     }
#   ]
# }

# ============================================================
# Bastion Host에서 수동 설치 명령어:
# ============================================================
# 
# 1. ALB Controller 설치:
# kubectl create serviceaccount aws-load-balancer-controller -n kube-system
# kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
#   eks.amazonaws.com/role-arn=arn:aws:iam::703671922786:role/myeks-alb-controller
# 
# helm repo add eks https://aws.github.io/eks-charts
# helm repo update
# helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
#   -n kube-system \
#   --set clusterName=myeks \
#   --set serviceAccount.create=false \
#   --set serviceAccount.name=aws-load-balancer-controller \
#   --set region=ap-northeast-2 \
#   --set vpcId=vpc-0524d7d5820340a16
# 
# 2. ArgoCD 설치:
# kubectl create namespace argocd
# helm repo add argo https://argoproj.github.io/argo-helm
# helm repo update
# helm install argo-cd argo/argo-cd \
#   -n argocd \
#   --set configs.params.server.insecure=true \
#   --set server.service.type=LoadBalancer
# ============================================================
