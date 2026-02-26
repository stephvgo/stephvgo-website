terraform {
  backend "s3" {
    bucket = "steph-tfstate-bucket"
    key    = "terraform/state.tfstate"
    region = "us-east-1"
  }
}
