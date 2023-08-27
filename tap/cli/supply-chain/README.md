## Overview

This folder contains a variety of options for installing TAP on the clusters.

## tap-view

There are two options for installing the developer portal on the View cluster. The one chosen depends on whether there is one Run cluster or two. When setting up the View cluster, it needs to be able to communicate with the other clusters in the TAP setup.

If there are two run clusters, one on EKS, and the other on AKS, run the following script.

    ~/aria-operations/tap/cli/supply-chain/01-eks-ootb-basic-view-two-run.sh


