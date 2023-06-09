resource "kubernetes_manifest" "ingress_ingressvote" {
  manifest = {
    "apiVersion" = "networking.k8s.io/v1"
    "kind" = "Ingress"
    "metadata" = {
      "namespace" = "default"
      "annotations" = {
        "kubernetes.io/ingress.class" = "azure/application-gateway"
      }
      "name" = "ingressvote"
    }
    "spec" = {
      "rules" = [
        {
          "host" = "voteapp.distributeur-de-pain.best"
          "http" = {
            "paths" = [
              {
                "backend" = {
                  "service" = {
                    "name" = "clustvoteapp"
                    "port" = {
                      "number" = 80
                    }
                  }
                }
                "path" = "/"
                "pathType" = "Prefix"
              },
            ]
          }
        },
        {
          "host" = "grafana.distributeur-de-pain.best"
          "http" = {
            "paths" = [
              {
                "backend" = {
                  "service" = {
                    "name" = "grafana"
                    "port" = {
                      "number" = 80
                    }
                  }
                }
                "path" = "/"
                "pathType" = "Prefix"
              },
            ]
          }
        },
        {
          "host" = "prometheus.distributeur-de-pain.best"
          "http" = {
            "paths" = [
              {
                "backend" = {
                  "service" = {
                    "name" = "prometheus-server"
                    "port" = {
                      "number" = 80
                    }
                  }
                }
                "path" = "/"
                "pathType" = "Prefix"
              },
            ]
          }
        },
      ]
    }
  }
}

resource "kubernetes_manifest" "deployment_redis" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "namespace" = "default"
      "labels" = {
        "app" = "redislb"
      }
      "name" = "redis"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app" = "redislb"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "redislb"
          }
        }
        "spec" = {
          "containers" = [
            {
              "args" = [
                "--requirepass",
                "$(REDIS_PWD)",
              ]
              "env" = [
                {
                  "name" = "ALLOW_EMPTY_PASSWORD"
                  "value" = "no"
                },
                {
                  "name" = "REDIS_PWD"
                  "valueFrom" = {
                    "secretKeyRef" = {
                      "key" = "password"
                      "name" = "redispw"
                    }
                  }
                },
              ]
              "image" = "redis"
              "name" = "redis"
              "ports" = [
                {
                  "containerPort" = 6379
                  "name" = "redis"
                },
              ]
              "resources" = {
                "limits" = {
                  "cpu" = "500m"
                  "memory" = "200Mi"
                }
                "requests" = {
                  "cpu" = "250m"
                  "memory" = "100Mi"
                }
              }
              "volumeMounts" = [
                {
                  "mountPath" = "/data"
                  "name" = "vol"
                },
              ]
            },
          ]
          "volumes" = [
            {
              "name" = "vol"
              "persistentVolumeClaim" = {
                "claimName" = "redisclaim"
              }
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "service_clustredis" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Service"
    "metadata" = {
      "namespace" = "default"
      "name" = "clustredis"
    }
    "spec" = {
      "ports" = [
        {
          "port" = 6379
        },
      ]
      "selector" = {
        "app" = "redislb"
      }
      "type" = "ClusterIP"
    }
  }
}

resource "kubernetes_manifest" "secret_redispw" {
  manifest = {
    "apiVersion" = "v1"
    "data" = {
      "password" = "cGFzc3dvcmQ="
    }
    "kind" = "Secret"
    "metadata" = {
      "namespace" = "default"
      "name" = "redispw"
    }
    "type" = "Opaque"
  }
}

resource "kubernetes_manifest" "storageclass_redisstor" {
  manifest = {
    "allowVolumeExpansion" = true
    "apiVersion" = "storage.k8s.io/v1"
    "kind" = "StorageClass"
    "metadata" = {
      "name" = "redisstor"
    }
    "parameters" = {
      "skuName" = "Standard_LRS"
    }
    "provisioner" = "kubernetes.io/azure-disk"
  }
}

resource "kubernetes_manifest" "persistentvolumeclaim_redisclaim" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "PersistentVolumeClaim"
    "metadata" = {
      "namespace" = "default"
      "name" = "redisclaim"
    }
    "spec" = {
      "accessModes" = [
        "ReadWriteOnce",
      ]
      "resources" = {
        "requests" = {
          "storage" = "1Gi"
        }
      }
      "storageClassName" = "redisstor"
    }
  }
}

resource "kubernetes_manifest" "deployment_voteapp" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "namespace" = "default"
      "labels" = {
        "app" = "voteapplb"
      }
      "name" = "voteapp"
    }
    "spec" = {
      "replicas" = 2
      "selector" = {
        "matchLabels" = {
          "app" = "voteapplb"
        }
      }
      "template" = {
        "metadata" = {
          "namespace" = "default"
          "labels" = {
            "app" = "voteapplb"
          }
        }
        "spec" = {
          "containers" = [
            {
              "env" = [
                {
                  "name" = "REDIS"
                  "value" = "clustredis"
                },
                {
                  "name" = "STRESS_SECS"
                  "value" = "2"
                },
                {
                  "name" = "REDIS_PWD"
                  "valueFrom" = {
                    "secretKeyRef" = {
                      "key" = "password"
                      "name" = "redispw"
                    }
                  }
                },
              ]
              "image" = "grabibel/voteapp_brief8_gs:1.0.123"
              "name" = "voteapp"
              "ports" = [
                {
                  "containerPort" = 80
                },
              ]
              "resources" = {
                "limits" = {
                  "cpu" = "500m"
                  "memory" = "1000Mi"
                }
                "requests" = {
                  "cpu" = "250m"
                  "memory" = "100Mi"
                }
              }
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "horizontalpodautoscaler_autoscalevoteraja" {
  manifest = {
    "apiVersion" = "autoscaling/v1"
    "kind" = "HorizontalPodAutoscaler"
    "metadata" = {
      "namespace" = "default"
      "name" = "autoscalevoteraja"
    }
    "spec" = {
      "maxReplicas" = 8
      "minReplicas" = 2
      "scaleTargetRef" = {
        "apiVersion" = "apps/v1"
        "kind" = "Deployment"
        "name" = "voteapp"
      }
      "targetCPUUtilizationPercentage" = 70
    }
  }
}

resource "kubernetes_manifest" "service_clustvoteapp" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Service"
    "metadata" = {
      "namespace" = "default"
      "name" = "clustvoteapp"
    }
    "spec" = {
      "ports" = [
        {
          "port" = 80
        },
      ]
      "selector" = {
        "app" = "voteapplb"
      }
      "type" = "ClusterIP"
    }
  }
}
