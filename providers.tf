terraform {
  required_providers {
    exoscale = {
      source  = "exoscale/exoscale"
      version = ">=0.31.1"
    }
  }
}

provider "exoscale" {
  timeout = 120
}
