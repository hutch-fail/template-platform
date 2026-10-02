# Partial S3-compatible backend for Cloudflare R2.
# Credentials: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (env only — never commit).
# Non-secret args: scripts/tofu-init.sh passes -backend-config from TF_BACKEND_*.
#
# Object key on platform-state:
#   template/terraform.tfstate
terraform {
  backend "s3" {}
}
