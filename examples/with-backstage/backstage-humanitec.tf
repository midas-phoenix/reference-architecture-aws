resource "humanitec_application" "backstage" {
  id   = "backstage"
  name = "backstage"
}

# Configure required values for backstage

resource "humanitec_value" "backstage_github_org_id" {
  app_id      = humanitec_application.backstage.id
  key         = "GITHUB_ORG_ID"
  description = ""
  value       = var.github_org_id
  is_secret   = false
}

resource "humanitec_value" "backstage_github_app_id" {
  app_id      = humanitec_application.backstage.id
  key         = "GITHUB_APP_ID"
  description = ""
  value       = local.github_app_id
  is_secret   = false
}

resource "humanitec_value" "backstage_github_app_client_id" {
  app_id      = humanitec_application.backstage.id
  key         = "GITHUB_APP_CLIENT_ID"
  description = ""
  value       = local.github_app_client_id
  is_secret   = true
}

resource "humanitec_value" "backstage_github_app_client_secret" {
  app_id      = humanitec_application.backstage.id
  key         = "GITHUB_APP_CLIENT_SECRET"
  description = ""
  value       = local.github_app_client_secret
  is_secret   = true
}

resource "humanitec_value" "backstage_github_app_private_key" {
  app_id      = humanitec_application.backstage.id
  key         = "GITHUB_APP_PRIVATE_KEY"
  description = ""
  value       = indent(2, local.github_app_private_key)
  is_secret   = true
}

resource "humanitec_value" "backstage_github_app_webhook_secret" {
  app_id      = humanitec_application.backstage.id
  key         = "GITHUB_APP_WEBHOOK_SECRET"
  description = ""
  value       = local.github_webhook_secret
  is_secret   = true
}

resource "humanitec_value" "backstage_humanitec_org" {
  app_id      = humanitec_application.backstage.id
  key         = "HUMANITEC_ORG_ID"
  description = ""
  value       = var.humanitec_org_id
  is_secret   = false
}

resource "humanitec_value" "backstage_humanitec_token" {
  app_id      = humanitec_application.backstage.id
  key         = "HUMANITEC_TOKEN"
  description = ""
  value       = var.humanitec_ci_service_user_token
  is_secret   = true
}

resource "humanitec_value" "backstage_cloud_provider" {
  app_id      = humanitec_application.backstage.id
  key         = "CLOUD_PROVIDER"
  description = ""
  value       = local.cloud_provider
  is_secret   = false
}

resource "humanitec_value" "aws_default_region" {
  app_id      = humanitec_application.backstage.id
  key         = "AWS_DEFAULT_REGION"
  description = ""
  value       = var.aws_region
  is_secret   = false
}

resource "random_bytes" "backstage_service_to_service_auth_key" {
  length = 24
}

resource "humanitec_value" "app_config_backend_auth_keys" {
  app_id      = humanitec_application.backstage.id
  key         = "APP_CONFIG_backend_auth_keys"
  description = "Backstage service-to-service-auth keys"
  value = jsonencode([{
    secret = random_bytes.backstage_service_to_service_auth_key.base64
  }])
  is_secret = true
}

# Configure required resources for backstage

locals {
  res_def_prefix = "backstage-"
}

# in-cluster postgres

module "backstage_postgres" {
  source = "git::https://github.com/humanitec-architecture/resource-packs-in-cluster.git//humanitec-resource-defs/postgres/basic"

  prefix = local.res_def_prefix
}

resource "humanitec_resource_definition_criteria" "backstage_postgres" {
  resource_definition_id = module.backstage_postgres.id
  app_id                 = humanitec_application.backstage.id

  force_delete = true
}

# k8s service account (to assume an AWS role)

module "backstage_k8s_service_account" {
  source = "git::https://github.com/humanitec-architecture/resource-packs-aws.git//humanitec-resource-defs/k8s/service-account"

  prefix = local.res_def_prefix
}

resource "humanitec_resource_definition_criteria" "backstage_k8s_service_account" {
  resource_definition_id = module.backstage_k8s_service_account.id
  app_id                 = humanitec_application.backstage.id

  force_delete = true
}

# AWS policy to create ECR repositories (required to scaffold apps)

module "backstage_iam_policy_ecr_create_repository" {
  source = "git::https://github.com/humanitec-architecture/resource-packs-aws.git//humanitec-resource-defs/iam-policy/ecr-create-repository"

  driver_account         = module.base.humanitec_resource_account_id
  resource_packs_aws_rev = var.resource_packs_aws_rev
  region                 = var.aws_region

  prefix = local.res_def_prefix
}

resource "humanitec_resource_definition_criteria" "backstage_iam_policy_ecr_create_repository" {
  resource_definition_id = module.backstage_iam_policy_ecr_create_repository.id
  app_id                 = humanitec_application.backstage.id

  force_delete = true
}

# AWS role assumable by the k8s service account

module "backstage_iam_role_service_account" {
  source = "git::https://github.com/humanitec-architecture/resource-packs-aws.git//humanitec-resource-defs/iam-role/service-account"

  driver_account         = module.base.humanitec_resource_account_id
  resource_packs_aws_rev = var.resource_packs_aws_rev
  region                 = var.aws_region

  policy_classes = ["default"]

  cluster_name = module.base.eks_cluster_name
  prefix       = local.res_def_prefix
}

resource "humanitec_resource_definition_criteria" "backstage_iam_role_service_account" {
  resource_definition_id = module.backstage_iam_role_service_account.id
  app_id                 = humanitec_application.backstage.id

  force_delete = true
}

# Workload resource that sets the service account

module "backstage_workload" {
  source = "git::https://github.com/humanitec-architecture/resource-packs-aws.git//humanitec-resource-defs/workload/service-account"

  prefix = local.res_def_prefix
}

resource "humanitec_resource_definition_criteria" "backstage_workload" {
  resource_definition_id = module.backstage_workload.id
  app_id                 = humanitec_application.backstage.id

  force_delete = true
}


# Configure required resources for scaffolded apps

# in-cluster mysql

module "backstage_mysql" {
  source = "git::https://github.com/humanitec-architecture/resource-packs-in-cluster.git//humanitec-resource-defs/mysql/basic"

  prefix = local.res_def_prefix
}

resource "humanitec_resource_definition_criteria" "backstage_mysql" {
  resource_definition_id = module.backstage_mysql.id
  env_type               = module.base.environment
}
