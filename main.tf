terraform {
  required_providers {
    local = {
      source = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

resource "local_file" "hello" {
  content = "Hello, World!"
  filename = "hello.txt"
}

output "greeting" {
  value = local_file.hello.content
}
