# OpenDroneMap Azure using Terraform

Server builds to run OpenDroneMap in Azure using Terraform.

## Requirements

- Git - to download repository
- Terraform - to build environment
- AZ CLI (Optional) - Helpful for querying Azure resources
- Visual Studio Code (Optional) - Helpful for editing build

### Create variables.tfvars

This file is optional, but without it, will require you to add these variables to your environment. You can use AZ CLI commands to get these attributes. Create `variables.tfvars` and add the following.

```
TF_VAR_ARM_CLIENT_ID       = "the client id"
TF_VAR_ARM_CLIENT_SECRET   = "client secret"
TF_VAR_ARM_SUBSCRIPTION_ID = "ID of the subscription to build in"
TF_VAR_ARM_TENANT_ID       = "tenant ID"
pub_key_data               = "ssh-rsa [the rest of the ssh public key]"
```

### Rclone
This build leverages Rclone config from the local computer. Suggest setting up Rclone and connect to any resource expected to use in Azure. This will be stored in `rclone.conf`. The `rclone.conf` will be copied to the virtual machine in Azure.

### Edit `variables.tf`

Review and edit `variables.tf`.

## Build

Once `variables.tf` and `variables.tfvars` are edited, open a shell prompt

- terraform init # run to download the necessary provisioners for Azure
- terraform fmt # quick format of the build files
- terraform plan -var-file=variables.tfvars # performs a syntax check against the environment
- terraform apply -var-file=variables.tfvars # executes the build
- terraform apply -var-file=variables.tfvars -destroy # burns down the environment

## access the build

Since the build will generate new public IP addresses, SSH access will add a lot of new entries over time. Suggest using the following:

	ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa_webodm.pem odm@[public IP address]
