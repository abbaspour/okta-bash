variable "okta_org_name" {
  type        = string
  description = "Okta org name"
}

variable "okta_base_url" {
  type = string
  description = "okta.com | oktapreview.com"
  default = "okta.com"
}

variable "okta_api_token" {
  type = string
  sensitive = true
}

variable "default_password" {
  type = string
  description = "password for test users"
  sensitive = true
}

variable "social_google_client_secret" {
  type = string
  description = "google social federation client_secret"
  sensitive = true
}