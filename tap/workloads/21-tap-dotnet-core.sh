#!/bin/bash

app_name=example-app
git_app_url=https://github.com/marlonajgayle/Net6WebApiTemplate

tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web \
    --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} \
    --build-env BP_DOTNET_PROJECT_PATH=src/Content/src/Net6WebApiTemplate.Api --yes

app_name=acme-fitness-web

tanzu apps workload create $app_name --image gcr.io/vmwarecloudadvocacy/acmeshop-front-end:rel1 --type web \
    --label app.kubernetes.io/part-of=${app_name}

#gcr.io/vmwarecloudadvocacy/acmeshop-front-end:1.0.0 | 2.2.0

apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: example-app
  labels:
    apps.tanzu.vmware.com/workload-type: web
    apps.tanzu.vmware.com/has-tests:  "true"
    app.kubernetes.io/part-of: sample-app
    tanzu.app.live.view: "true"
    tanzu.app.live.view.application.flavours: steeltoe
    tanzu.app.live.view.application.name: steeltoe-weatherforecast
spec:
  build:
    env:
    - name: BP_DOTNET_PROJECT_PATH
      value: "src/Content/src/Net6WebApiTemplate.Api"
  source:
    git:
      url: https://github.com/marlonajgayle/Net6WebApiTemplate
      ref:
        branch: develop
    # subPath: src/Content/src/Net6WebApiTemplate.Api/

apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: tap-dotnet-core
  labels:
    apps.tanzu.vmware.com/workload-type: web
    apps.tanzu.vmware.com/has-tests:  "true"
    app.kubernetes.io/part-of: tap-dotnet-core
    tanzu.app.live.view: "true"
spec:
  build:
    env:
    - name: BP_DOTNET_PROJECT_PATH
      value: "Tap.Dotnet.Core.Web.Mvc"
  source:
    git:
      url: https://github.com/nycpivot/tap-dotnet-core
      ref:
        branch: main

