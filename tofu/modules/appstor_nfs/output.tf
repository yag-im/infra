output "pvcs" {
  value = [ for pvc in kubernetes_persistent_volume_claim.appstor_pvc_nfs: {
      "name": pvc.metadata.0.name,
      "region": pvc.metadata.0.labels["region"]
    } 
  ]
}
