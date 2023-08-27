## Overview

This repository was built for running two TAP Run clusters, one for a .NET Core Web MVC application hosted on an AWS EKS cluster (tap-run-eks), and a second .NET Core WebAPI application hosted on an Azure AKS cluster (tap-run-aks), which can be accessed by the Web MVC application.

This folder contains the scripts for installing TAP with or without TMC.

## Multicluster TAP with TMC

### Prerequisites

* Three EKS clusters, 1) tap-view, 2) tap-build, 3) tap-run-eks.
* One AKS cluster, 1) tap-run-aks.

Both of these scripts will install tanzu-cluster-essentials in each of their respective clusters. Then it will export the TAP packages from the source tanzunet registry and import them into the registry of your choice. Finally, it will clone the sample tanzu-java-web-app to the operator machine.

    01-tap-multi-aws-tmc-prereqs.sh
    02-tap-multi-azure-tmc-prereqs.sh

## Multicluster TAP without TMC

To install a multicluster TAP environment without TMC, run the scripts in multi-cf. This will use a CloudFormation stack for spinning up the three EKS clusters. The second script will create the second Run cluster.

    ~/aria-operations/tap/cli/multi-cf/01-tap-multi-aws-prereqs.sh
    ~/aris-operations/tap/cli/multi-cf/02-tap-azure-prereqs.sh

## TAP Build Cluster only (TDP)

The following script will create a TAP Build cluster only for build Tanzu Developer Portal (TDP) images.

    ~/aria-operations/tap/cli/build-cf/01-tap-build-aws-prereqs.sh

## Next Steps

Once we have finished the above steps (for either scenario), we are ready to install TAP packages from our target registry into each of our clusters. We'll run the scripts in the [supply-chain](supply-chain) folder next.
