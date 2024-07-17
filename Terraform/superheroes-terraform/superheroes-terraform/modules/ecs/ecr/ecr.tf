variable "containers"         { }
variable "tags"               { }

resource "aws_ecr_repository" "main" {
  count = length(var.containers) > 0 ? length(var.containers) : 0

  name                 = "${lookup(var.containers[count.index], "name", null)}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags  = merge(
    var.tags,
    { Name = lookup(element(var.containers, count.index), "family") },
  )
}
