output "service_url" {
  description = "Cloud Run サービスの URL"
  value       = google_cloud_run_v2_service.mcp.uri
}

output "mcp_endpoint" {
  description = "MCP (Streamable HTTP) エンドポイント"
  value       = "${google_cloud_run_v2_service.mcp.uri}/mcp"
}

output "image_repository" {
  description = "コンテナイメージのプッシュ先"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.mcp.repository_id}"
}

output "workload_identity_provider" {
  description = "GitHub Actions の変数 GCP_WORKLOAD_IDENTITY_PROVIDER に設定する値"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deployer_service_account" {
  description = "GitHub Actions の変数 GCP_DEPLOYER_SERVICE_ACCOUNT に設定する値"
  value       = google_service_account.github_deployer.email
}
