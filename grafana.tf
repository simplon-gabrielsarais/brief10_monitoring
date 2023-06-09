resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "http://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace = "default"
  provisioner "local-exec" {
  command = <<EOT
            "helm upgrade --install promtail grafana/promtail"
            "helm install loki grafana/loki-stack"
  EOT
  }
}