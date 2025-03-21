resource "kubernetes_deployment" "webapi" {
  metadata {
    name = "webapi-deployment"
    labels = {
      app = "webapi"
    }
    namespace = var.k8s_namespace
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = "webapi"
      }
    }
    template {
      metadata {
        labels = {
          app = "webapi"
        }
      }
      spec {
        container {
          image             = var.docker_image
          image_pull_policy = "IfNotPresent"
          name              = "webapi"
          port {
            container_port = 80
          }
          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "125m"
              memory = "50Mi"
            }
          }
          env_from {
            config_map_ref {
              name = "webapi-cm"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webapi" {
  metadata {
    name      = "webapi"
    namespace = var.k8s_namespace
  }
  spec {
    selector = {
      app = "webapi"
    }
    port {
      port = 80
      name = "http"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "webapi" {
  metadata {
    name      = "webapi-cm"
    namespace = var.k8s_namespace
  }
  data = {
    FLASK_DEBUG                     = true
    FLASK_ENV                       = var.flask_env
    FLASK_PROPAGATE_EXCEPTIONS      = true
    FLASK_SQLALCHEMY_ENGINE_OPTIONS = jsonencode({ "pool_pre_ping" : true, "pool_size" : 10, "pool_recycle" : 120 })
    APPSVC_URL                      = "http://appsvc.default.svc.cluster.local"
    BEHIND_PROXY                    = var.behind_proxy
    SQLDB_DBNAME                    = "yag"
    SQLDB_HOST                      = "sqldb.default.svc.cluster.local"
    SQLDB_PORT                      = 5432
    SQLDB_USERNAME                  = "authsvc"
    OAUTHLIB_INSECURE_TRANSPORT     = var.oauthlib_insecure_transport
    OAUTHLIB_RELAX_TOKEN_SCOPE      = var.oauthlib_relax_token_scope
    #secrets
    FLASK_SECRET_KEY             = var.flask_secret_key
    FLASK_SECURITY_PASSWORD_SALT = var.flask_security_password_salt
    SIGSVC_AUTH_TOKEN            = var.sigsvc_auth_token
    SQLDB_PASSWORD               = var.sqldb_password
    DISCORD_OAUTH_CLIENT_ID      = var.discord_oauth_client_id
    DISCORD_OAUTH_CLIENT_SECRET  = var.discord_oauth_client_secret
    GOOGLE_OAUTH_CLIENT_ID       = var.google_oauth_client_id
    GOOGLE_OAUTH_CLIENT_SECRET   = var.google_oauth_client_secret
    REDDIT_OAUTH_CLIENT_ID       = var.reddit_oauth_client_id
    REDDIT_OAUTH_CLIENT_SECRET   = var.reddit_oauth_client_secret
    TWITCH_OAUTH_CLIENT_ID       = var.twitch_oauth_client_id
    TWITCH_OAUTH_CLIENT_SECRET   = var.twitch_oauth_client_secret
  }
}
