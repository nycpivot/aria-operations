# Aria Tanzu Operations

This repository will demonstrate the automated deployment of a simple microservices application deployed across different platforms and cloud environments with the following VMware Aria and Tanzu products and services.

* Tanzu Application Platform (TAP), a multicluster installation consisting of a 1) View Cluster (tap-view), a portal for developers to monitor, manage, and discover organization resources in a single location, a 2) Build Cluster (tap-build), a complete end-to-end automated supply chain for compiling and building source code into an OCI-compliant container image ready for deployment, and 3) Run Cluster(s), where the application and its dependent services are run and accessed by users.

This repository was built for running two TAP Run clusters, one for a .NET Core Web MVC application hosted on an AWS EKS cluster (tap-run-eks), and a second .NET Core WebAPI application hosted on an Azure AKS cluster (tap-run-aks), which can be accessed by the Web MVC application.

* Tanzu Mission Control (TMC), will be used to provision a multicluster TAP environment hosting a developer portal on a View cluster,

* Tanzu Service Mesh (TSM), all of our applications and services hosted on TAP Run clusters will be encapsulated in a Global Namespace (GNS).

* Tanzu Observability (TO/TOS), we will monitor resources and traces of both applications across cloud environments.

The following diagram illustrates the full architecture of the system.

(https://github.com/nycpivot/aria-operations/tree/v1.6.1/refs/aria-tanzu.png)

## Getting Started

### Optional

1) The following is optional if you want to create a clean jumpbox and run a script to install all the required tools. First, clone this repository to your local machine and run the following script from within the cloned aria-operations folder. This script will generate the private SSH key and download it into the operator/keys folder. It will create the folder if it doesn't already exist. If you fork the repository, it is advised to include keys/ in the .gitignore file so you don't mistakenly push private keys to a public repository.

    * [01-aria-operator-new.sh](01-aria-operator-new.sh), this script will execute an AWS CloudFormation stack from the operator/config folder, that will create an EC2 instance in the specified region and the default network.

If successful, the script will out the DNS name of the new jumpbox. Copy and paste this into the aria-operator.sh file and overwrite the existing DNS name for the respective region. This file can be used for hosts created in other regions

2) Run sh aria-operator.sh. Once logged in, clone this same repository again, and specify the branch v1.6.1.

    git clone https://github.com/nycpivot/aria-operations -b v1.6.1

    * [02-tanzu-operator-prereqs.sh](02-tanzu-operator-prereqs.sh), this script installs all the prerequisites necessary for the workshop. You will need your AWS Access Key and Secret.

On the jumpbox, it is recommended to run these from the directory above the cloned repository, as some scripts might include relative path references.

    bash aria-operations/02-operator-prereqs.sh

## Prerequisites

All subsequent scripts retrieve secrets from AWS Secrets Manager. Or, you can edit the files and set these variables manually.

* pivnet-username
* pivnet-password
* pivnet-token
* tmc-token
* tsm-token
* registry-secret (any container registry that requires a username and password/secret to login)
* github-token (GitOps only)


03-tanzu-prereqs-aws.sh
04-tanzu-vpc-stack.sh

Follow the steps here to provision clusters in TMC.
Follow the steps here to install and configure the TAP clusters.

Now we are ready to provision our TAP clusters with TMC.

aria-operations/tmc/01-tap-clusters-aws-cli.sh
aria-operations/tap/cli/multi-cf/11-tap-azure-prereqs.sh # creates the AKS cluster to attach
aria-operations/tmc/03-tap-clusters-azure-attach-cli.sh # attach AKS cluster

TAP
aria-operations/tap/cli/multi-tmc/01-tap-multi-aws-tmc-prereqs.sh
aria-operations/tap/cli/supply-chain/01-eks-ootb-basic-view-two-run.sh # for two run clusters (EKS, AKS)




Once these prerequisites have been met, the operator has the following options for the TAP installation.

## TAP Installation

### Architecture

* [Single Cluster](full-profile), all the components of TAP can be run on a single cluster, also known as Full Profile. This is the easiest and quickest setup for learning the basics of TAP.

* [Multi Cluster](multi-profile), the components are assigned to separate clusters based on their function, also known as Multi-Profile. This architecture is preferred for production environments. For example, application builds are managed separate from live application workloads.

The multi-profile architecture lends itself to scaling clusters differently according to usage. For example, application workloads on the Run cluster can scale more or less nodes depending on the usage, without the need to scale a build cluster.

For a complete reference architecture, see [TAP Reference Architecture](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap-reference-architecture/GUID-reference-designs-tap-architecture-planning.html)

### Installation Types

* [CLI](cli), relies solely on the Tanzu CLI and TAP plugins.
* [GitOps](gitops), uses mostly configuration files stored in a Git repository, and limited Tanzu CLI.

## Goals

The following is a common set of use-cases explored in this repository that most operators and developers will encounter.

* [TAP Services Toolkit](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/index.html), used to make backend services, such as, databases, caches, queues, and more, easily discoverable across numerous disparate platforms and to bind the connection details to application workloads.
