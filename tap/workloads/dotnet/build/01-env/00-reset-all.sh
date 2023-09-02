#!/bin/bash

app_branch=tap-dotnet-core-env

kubectl config use-context tap-build

kubectl delete ns ${app_branch} --ignore-not-found
