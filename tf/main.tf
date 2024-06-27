resource "okta_group" "okta-bash-users" {
  name = "Okta Bash Users"
}

resource "okta_user" "test-user-1" {
  email      = "user@atko.email"
  first_name = "Amin"
  last_name  = "Abbaspour"
  login      = "user@atko.email"
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
  label                     = "JWT.io"
  type                      = "browser"
  grant_types               = ["implicit", "authorization_code"]
  response_types            = ["token", "id_token", "code"]
  redirect_uris             = ["https://jwt.io/"]
  post_logout_redirect_uris = [
    "https://jwt.io/"
  ]
  token_endpoint_auth_method = "none"
  pkce_required              = true
}

output "jwt-io-client-id" {
  value = okta_app_oauth.jwt-io.client_id
}

resource "okta_idp_social" "google" {
  name          = "google"
  scopes        = ["openid", "profile", "email"]
  type          = "GOOGLE"
  protocol_type = "OIDC"
  client_id     = "579602309292-sepqhui79mfiinoast9rs6n1dg7dt26f.apps.googleusercontent.com"
  client_secret = var.social_google_client_secret
}

## todo: 1st factory policy for jwt.io app