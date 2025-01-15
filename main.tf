terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}



module "vpc" {
  source = "./modules/vpc"

  prefix    = var.environment_name
  separator = "-"
  name      = "streamsong"

  vpc_cidr_block = var.vpc_cidr_block
}

module "mwaa" {
  source = "./modules/mwaa"

  prefix    = var.environment_name
  separator = "-"
  name      = "streamsong"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
}


