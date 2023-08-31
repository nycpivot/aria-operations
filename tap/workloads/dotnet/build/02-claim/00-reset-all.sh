#!/bin/bash

kubectl config use-context tap-build

kubectl delete all -l secret-type=claim
