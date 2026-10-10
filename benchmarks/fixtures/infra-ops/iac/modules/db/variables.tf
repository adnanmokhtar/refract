variable "identifier" {
  type = string
}

variable "instance_class" {
  type    = string
  default = "db.r7g.large"
}

variable "allocated_storage" {
  type    = number
  default = 100
}

variable "master_username" {
  type    = string
  default = "larder_admin"
}

variable "master_password" {
  type        = string
  description = "Master password, passed in from the environment root."
}

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "subnet_group" {
  type = string
}
