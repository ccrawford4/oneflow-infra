variable "region" {
    description = "The AWS region to launch resources."
    type = string
}

variable "environment" {
    description = "The environment in which the resources are deployed."
    type = string
}

variable "ami" {
    description = "The Amazon Machine Image used to deploy the EC2 instance."
    type = string
}