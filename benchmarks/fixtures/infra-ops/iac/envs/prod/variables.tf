variable "azs" {
  type    = list(string)
  default = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
}

variable "partner_queues" {
  type        = list(string)
  description = "One inbound queue per logistics partner, in onboarding order."
  default     = ["parcelnow", "fastlane", "citycourier"]
}

variable "orders_db_password" {
  type      = string
  sensitive = true
}

variable "enable_debug_host" {
  type    = bool
  default = false
}

variable "office_vpn_ip" {
  type    = string
  default = "198.51.100.10"
}
