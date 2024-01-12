terraform {
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 4.6.3"
    }
  }
}

provider "okta" {
  org_name    = var.okta_org_name
  base_url    = "okta.com"
  client_id   = "0oa3jqopq7CejpxBl3l7"
  private_key = "converted-tf-private-key.pem"
  scopes      = [
    "okta.groups.manage",
    "okta.apps.manage",
    "okta.clients.manage",
    "okta.policies.manage",
    "okta.users.manage"
  ]
  log_level = 1
}