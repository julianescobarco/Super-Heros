#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios para Task Definition
#--------------------------------------------------------------

variable "containers"               { }
variable "tags"                     { }
variable "dns_lb"                   { }
variable "ecs_task_role"            { }
variable "ecs_task_exec_role"       { }
variable "region"                   { }
variable "extra_template_variables" {}
variable "volumen_configuration" {
  default = null
}

resource "aws_ecr_repository" "main" {
  count = length(var.containers) > 0 ? length(var.containers) : 0

  name                 = lookup(var.containers[count.index], "name", null)
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags  = merge(
    var.tags,
    { Name = lookup(element(var.containers, count.index), "family") },
  )
}


resource "aws_ecs_task_definition" "app" {
  count                     = length(var.containers) 
  family                    = lookup(element(var.containers, count.index), "family")
  network_mode              = lookup(element(var.containers, count.index), "network_mode")
  cpu                       = lookup(element(var.containers, count.index), "cpu")
  memory                    = lookup(element(var.containers, count.index), "memory")
  requires_compatibilities  = ["FARGATE"]

  dynamic "volume" {
    for_each = lookup(var.containers[count.index], "volumen_index", null) == null ? [] : lookup(var.containers[count.index], "volumen_index", null)
    content {
      name      = lookup(element(var.volumen_configuration, volume.value), "volume_name", null)
      host_path = lookup(element(var.volumen_configuration, volume.value), "host_path", null)
      dynamic "efs_volume_configuration" {
        for_each = lookup(element(var.volumen_configuration, volume.value), "volume_type", null) == "EFS" ? [true] : []
        content {
          file_system_id          = lookup(element(var.volumen_configuration, volume.value), "file_system_id", null)
          root_directory          = lookup(element(var.volumen_configuration, volume.value), "root_directory", null)
          transit_encryption      = lookup(element(var.volumen_configuration, volume.value), "transit_encryption", null)
          transit_encryption_port = lookup(element(var.volumen_configuration, volume.value), "transit_encryption_port", null)
          authorization_config{
              access_point_id = lookup(element(var.volumen_configuration, volume.value), "access_point_id", null)
              iam             = lookup(element(var.volumen_configuration, volume.value), "iam", null)
          }
        }
      }
    }
  }

  container_definitions = templatefile(lookup(element(var.containers, count.index), "container_definitions"), "${merge("${var.extra_template_variables}",
  {
      dns_lb = var.dns_lb
      image_url = "${element(aws_ecr_repository.main.*.repository_url, count.index)}"
      region = var.region
  })}")

  task_role_arn = var.ecs_task_role
  execution_role_arn = var.ecs_task_exec_role

  tags  = merge(
    var.tags,
    { Name = lookup(element(var.containers, count.index), "family") },
  )
}

output "family" { value = "${aws_ecs_task_definition.app.*.family}" }
output "revision" { value = "${aws_ecs_task_definition.app.*.revision}" }
