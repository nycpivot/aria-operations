"waiting to read value [.status.latestImage] from resource [image.kpack.io/tanzu-java-web-app] in namespace [default]"

This occurred on build cluster after running "tanzu apps workload create"

While this can happen for different reasons, in this case, there was a problem configuring multiple run clusters to communicate with view cluster because one of the run clusters (AKS) was not available in kube config, which resulted in configuring two run clusters with the same token from the existent cluster.