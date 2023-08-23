# Aria Tanzu Operations

This repository will demonstrate the automated deployment of a simple microservices application deployed across different platforms and cloud environments with the following VMware Aria and Tanzu products and services.

* Tanzu Application Platform (TAP), a multicluster installation consisting of a 1) View Cluster (tap-view), a portal for developers to monitor, manage, and discover organization resources in a single location, a 2) Build Cluster (tap-build), a complete end-to-end automated supply chain for compiling and building source code into an OCI-compliant container image ready for deployment, and 3) Run Cluster(s), where the application and its dependent services are run and accessed by users.

This repository was built for running two TAP Run clusters, one for a .NET Core Web MVC application hosted on an AWS EKS cluster (tap-run-eks), and a second .NET Core WebAPI application hosted on an Azure AKS cluster (tap-run-aks), which can be accessed by the Web MVC application.

* Tanzu Mission Control (TMC), will be used to provision a multicluster TAP environment hosting a developer portal on a View cluster,

* Tanzu Service Mesh (TSM), all of our applications and services hosted on TAP Run clusters will be encapsulated in a Global Namespace (GNS).

* Tanzu Observability (TO/TOS), we will monitor resources and traces of both applications across cloud environments.

The following diagram illustrates the full architecture of the system.





VMware Tanzu Application Platform (TAP) is a complete end-to-end supply chain capable of monitoring a source code repository for changes, compiling and building executable binaries packaged into OCI-conformant containers, deployed to any Kubernetes cluster running on-premises or a public cloud provider. This requires several different components with different responsibilities communicating with one another.

This repository offers application developers and operators practical examples for getting started with TAP (Tanzu Application Platform) on AWS with any Container Registry, except Elastic Container Registry (ECR). To run a workshop using ECR, refer to that [repository](https://github.com/nycpivot/tap-workshop-aws-ecr).

## Getting Started

### Optional

The following is optional if you want to create a clean jumpbox and install all the required tools.

* [01-aria-operator-new.sh](01-aria-operator-new.sh), this script will execute an AWS *CloudFormation stack that will create an EC2 instance in the default network.

The two scripts in the root directory can be run to bootstrap an Ubuntu Linux jumpbox in the target environment and install all prerequisites needed to run the workshop.


* [02-tanzu-operator-prereqs.sh](02-tanzu-operator-prereqs.sh), this script installs all the prerequisites necessary for the workshop. You will need your AWS Access Key and Secret.

If you prefer to operate the cluster on your local machine, the following prerequisites will be required.

*NOTE: The CloudFormation stack expects an existing Security Group and Key Pair.

## Prerequisites

* Docker
* AWS CLI
* kubectl
* helm, jq, etc...

This setup on AWS relies on secrets stored in AWS Secrets Manager. It's very easy to set this up, or you can modify the scripts to set these secrets as in code. The secrets required are as follows.

* 

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
