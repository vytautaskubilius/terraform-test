terraform {
  required_version = ">=0.12.29"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.69.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = ["473671374008"]
}

module "vpc_mgmt" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-app?ref=v0.12.4"

  aws_region       = "us-east-1"
  cidr_block       = "10.43.0.0/16"
  num_nat_gateways = 0
  vpc_name         = "v-app-test"

  create_private_persistence_subnets = false
  create_private_app_subnets = false
}

module "vpc_mgmt_nacls" {
  source = "git::git@github.com:gruntwork-io/module-vpc.git//modules/vpc-app-network-acls?ref=v0.12.4"

  num_subnets                            = module.vpc_mgmt.num_availability_zones
  private_app_subnet_cidr_blocks         = module.vpc_mgmt.private_app_subnet_cidr_blocks
  private_app_subnet_ids                 = module.vpc_mgmt.private_app_subnet_ids
  private_persistence_subnet_cidr_blocks = module.vpc_mgmt.private_persistence_subnet_cidr_blocks
  private_persistence_subnet_ids         = module.vpc_mgmt.private_persistence_subnet_ids
  public_subnet_cidr_blocks              = module.vpc_mgmt.public_subnet_cidr_blocks
  public_subnet_ids                      = module.vpc_mgmt.public_subnet_ids
  vpc_id                                 = module.vpc_mgmt.vpc_id
  vpc_name                               = module.vpc_mgmt.vpc_name

  create_private_persistence_subnet_nacls = false
  create_private_app_subnet_nacls = false
}

module "bastion" {
  # When using these modules in your own templates, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/module-server.git//modules/single-server?ref=v1.0.8"
  source = "git::git@github.com:gruntwork-io/module-server.git//modules/single-server?ref=v0.10.0"

  name             = "v-bastion-test"
  instance_type    = "t3.micro"
  ami              = "ami-074db80f0dc9b5f40"
  keypair_name     = "v-test"
  user_data_base64 = data.template_cloudinit_config.cloud_init.rendered

  vpc_id                   = module.vpc_mgmt.vpc_id
  subnet_id                = module.vpc_mgmt.public_subnet_ids[0]
  allow_ssh_from_cidr_list = ["0.0.0.0/0"]

  tags = {
    Foo = "Bar"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# USE CLOUD-INIT SCRIPT TO INITIALIZE THE BASTION
# The data sources below use a template and a cloud-init config snippet to set up the system on first boot.
# See the provider documentation: https://www.terraform.io/docs/providers/template/d/cloudinit_config.html
# ---------------------------------------------------------------------------------------------------------------------

data "template_cloudinit_config" "cloud_init" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "bastion-default-cloud-init"
    content_type = "text/x-shellscript"
    content      = data.template_file.user_data.rendered
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data.sh")
}
