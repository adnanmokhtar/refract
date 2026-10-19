variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "cluster_role_arn" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "ingress_lb_hostname" {
  type        = string
  description = "Hostname of the load balancer the ingress controller provisions."
}
