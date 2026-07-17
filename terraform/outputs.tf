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
