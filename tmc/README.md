## Prerequisites

* Installed and configured the AWS CLI.
* Installed and configured the tmc and tanzu mission-control CLI.

These steps would have been done in preceding steps setting up the operator machine.

    ~/aria-operations/tmc/create/01-tap-clusters-aws-cli.sh

This first script will perform the following steps.

* Execute a CloudFormation stack that will create IAM roles to be used for cross-account access by TMC for creating clusters.
* Create a TMC Cluster Group called (tmc-operations).
* Create an AWS Account Credential (aws-account-credential).
* Provision three EKS Clusters.

    * tap-view
    * tap-build
    * tap-run-eks

The next script will create an AKS cluster with the Azure CLI - not with TMC. This will demonstrate attaching existing clusters from any cloud platform.

    ~/aria-operations/tmc/attach/01-tap-clusters-azure-create-and-attach-cli.sh

That completes this section for setting up our TAP clusters on TMC.

Follow the steps [here](../tap) to configure the TAP clusters.
