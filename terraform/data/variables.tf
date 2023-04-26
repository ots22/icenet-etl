variable "project_name" {
    description = "Project name for resource naming"
    type    = string
}
variable "location" {
  description = "Which Azure location to build in"
  default     = "uksouth"
}
variable "default_tags" {
    description = "Default tags for resources"
    type    = map(string)
    default = {}
}
variable "subnet" {
    description = "Subnet to deploy in"
    type = string
}

# Local variables
locals {
  tags = merge(
    {
      "module" = "inputs"
    },
    var.default_tags,
  )
}
