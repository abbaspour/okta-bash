resource "okta_group" "okta-bash-users" {
  name = "Okta Bash Users"
}

resource "okta_user" "test-user-1" {
  email      = "amin@atko.email"
  first_name = "Amin"
  last_name  = "Abbaspour"
  login      = "amin@atko.email"
  password   = var.default_password
}

resource "okta_group_memberships" "test-users-group-membership" {
  group_id = okta_group.okta-bash-users.id
  users    = [okta_user.test-user-1.id]
}

resource "okta_app_group_assignment" "test-users-to-jwt-io" {
  app_id   = okta_app_oauth.jwt-io.id
  group_id = okta_group.okta-bash-users.id
}

resource "okta_app_oauth" "jwt-io" {
  label                      = "JWT.io"
  type                       = "browser"
  grant_types                = ["implicit", "authorization_code"]
  response_types             = ["token", "id_token", "code"]
  redirect_uris              = ["https://jwt.io/"]
  token_endpoint_auth_method = "none"
  pkce_required              = false
}

output "jwt-io-client-id" {
  value = okta_app_oauth.jwt-io.client_id
}

## todo: 1st factory policy for jwt.io app