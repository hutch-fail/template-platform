# Baseline: local backend (must fail the remote-backend language bar).
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
