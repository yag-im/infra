locals {
  host_otelcol_gw                  = "otelcol-gw-opentelemetry-collector"
  port_otelcol_gw                  = 4317
  port_otelcol_gw_prometheus       = 9090
  uri_loki                         = "http://loki-gateway.${var.k8s_namespace}:80/loki/api/v1/push"
  uri_otelcol_gw                   = "otelcol-gw-opentelemetry-collector:4317"
  uri_tempo                        = "http://fixme-tempo-gw.${var.k8s_namespace}:333"
  url_charts_grafana               = "https://grafana.github.io/helm-charts"
  url_charts_otel                  = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  url_charts_prometheus            = "https://prometheus-community.github.io/helm-charts"
  ver_charts_grafana_grafana       = "7.2.5"
  ver_charts_grafana_loki          = "5.42.0"
  ver_charts_otelcol               = "0.80.0"
  ver_charts_prometheus_kube_stack = "56.6.1"
  ver_charts_prometheus_prometheus = "25.11.0"
}

resource "kubernetes_namespace" "otel" {
  metadata {
    name = var.k8s_namespace
  }
}

/*
resource "helm_release" "otelcol-cluster" {
  name       = "otelcol-cluster"
  namespace  = var.k8s_namespace
  repository = local.url_charts_otel
  chart      = "opentelemetry-collector"
  version    = local.ver_charts_otelcol
  values = [
    templatefile("${path.module}/helm-values/otelcol-cluster.yaml", {
        uri_otelcol_gw = "${local.uri_otelcol_gw}",
    })
  ]
}*/

# scrapes logs on each node and forwards them to otelcol-gw
resource "helm_release" "otelcol-node" {
  name       = "otelcol-node"
  namespace  = var.k8s_namespace
  repository = local.url_charts_otel
  chart      = "opentelemetry-collector"
  version    = local.ver_charts_otelcol
  values = [
    templatefile("${path.module}/helm-values/otelcol-node.yaml", {
      uri_otelcol_gw = "${local.uri_otelcol_gw}",
    })
  ]
}

# receives logs from all nodes in the k8s and jukebox clusters
# from jukebox cluster receives also host metrics
resource "helm_release" "otelcol-gw" {
  name       = "otelcol-gw"
  namespace  = var.k8s_namespace
  repository = local.url_charts_otel
  chart      = "opentelemetry-collector"
  version    = local.ver_charts_otelcol
  values = [
    templatefile("${path.module}/helm-values/otelcol-gw.yaml", {
      port_otelcol_gw            = "${local.port_otelcol_gw}",
      port_otelcol_gw_prometheus = "${local.port_otelcol_gw_prometheus}",
      uri_loki                   = "${local.uri_loki}",
      uri_tempo                  = "${local.uri_tempo}",
    })
  ]
}

# logs storage, receives logs from otelcol-gw
resource "helm_release" "loki" {
  name       = "loki"
  namespace  = var.k8s_namespace
  repository = local.url_charts_grafana
  chart      = "loki"
  version    = local.ver_charts_grafana_loki
  values = [
    "${file("${path.module}/helm-values/loki.yaml")}"
  ]
}

# otlp-gw is a gateway between data producers (jukebox nodes) and receivers (loki and prometheus)
# otlp-gw has a dedicated port "listen"-ing for prometheus calls (pull mode)
resource "helm_release" "kube-prometheus-stack" {
  name       = "kube-prometheus-stack"
  namespace  = var.k8s_namespace
  repository = local.url_charts_prometheus
  chart      = "kube-prometheus-stack"
  version    = local.ver_charts_prometheus_kube_stack
  values = [
    templatefile("${path.module}/helm-values/kube-prometheus-stack.yaml", {
      host_otelcol_gw            = "${local.host_otelcol_gw}",
      port_otelcol_gw_prometheus = "${local.port_otelcol_gw_prometheus}",
    })
  ]
}

/*
resource "helm_release" "prometheus" {
  name       = "prometheus"
  namespace  = var.k8s_namespace
  repository = local.url_charts_prometheus
  chart      = "prometheus"
  version    = local.ver_charts_prometheus_prometheus
  values = [
    templatefile("${path.module}/helm-values/prometheus.yaml", {
        host_otelcol_gw = "${local.host_otelcol_gw}",
        port_otelcol_gw_prometheus = "${local.port_otelcol_gw_prometheus}",
    })
  ]
}
*/

resource "helm_release" "grafana" {
  name       = "grafana"
  namespace  = var.k8s_namespace
  repository = local.url_charts_grafana
  chart      = "grafana"
  version    = local.ver_charts_grafana_grafana
  values = [
    "${file("${path.module}/helm-values/grafana.yaml")}"
  ]
  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }
}
