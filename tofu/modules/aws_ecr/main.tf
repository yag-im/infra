resource "helm_release" "k8s_ecr_login_renew" {
  repository       = "https://nabsul.github.io/helm"
  chart            = "k8s-ecr-login-renew"
  name             = "k8s-ecr-login-renew"
  namespace        = "default"
  version          = "v1.0.2"
  cleanup_on_fail  = true
  force_update     = false
  set {
    name  = "awsRegion"
    value = var.aws_ecr_region
  }
  set {
    name  = "awsAccessKeyId"
    value = var.aws_ecr_access_key_id
  }
  set {
    name  = "awsSecretAccessKey"
    value = var.aws_ecr_secret_access_key
  }
  set {
    name = "dockerSecretName"
    value = var.aws_ecr_docker_secret_name
  }
  set {
    name = "registries"
    value = var.aws_ecr_registries
  }
}
