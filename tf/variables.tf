variable "okta_org_name" {
  type        = string
  description = "Okta org name"
}

variable "okta_tf_client_id" {
  type        = string
  description = "Terraform client_id"
}


variable "default_password" {
  type = string
  description = "password for test users"
  sensitive = true
}
