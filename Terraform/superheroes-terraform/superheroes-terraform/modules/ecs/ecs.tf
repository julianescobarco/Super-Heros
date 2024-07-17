#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios el Cluster ECS
#--------------------------------------------------------------

# Global Variable
variable "region"              { }
variable "name"                { }
variable "stack_id"            { }
variable "layer"               { }
variable "tags"                { }
# Variable Security
variable "vpc_id"              { }
variable "subnets"             { }
variable "ingress_rule"        { }
variable "private_subnet_ids"  { }
# Variable Logs
variable "logs_retention_in_days" {
  type        = number
  default     = 90
  description = "Specifies the number of days you want to retain log events"
}
#Variable ECS
variable "containers"               { }
variable "extra_template_variables" { default = {} }
variable "tg_names"                 { }
variable "http_rules"               { }
variable "create_listener_https"    { default = false }
variable "s3_certs"                 { default = null }
variable "internal_lb"              { default = true }
variable "default_action_listener_http" { default = {} }
variable "default_action_listener_https" { default = {} }
variable "alb_subnet_ids"           { default = null }
variable "custom_policy"            { default = [] }
variable "policy_attachment"        { default = [] }
variable "certificate_arn"          { default = null }
variable "lb_dns_name"              { default = null }
variable "sg_id"                    { }
variable "lb_listener_arn"          { }
variable "ecs_cluster_id"           { }
variable "ecs_cluster_name"         { }
variable "volumen_configuration" {
  default = null
}

locals {
  lb_subnets_ids = var.internal_lb  == true ? var.private_subnet_ids : var.alb_subnet_ids
}
/*
module "sg_ecs" {
  source = "../../security/security_group"

  name = var.name
  tags = var.tags
  vpc_id = var.vpc_id
  ingress_rule = var.ingress_rule
  cidrs = var.subnets
}

module "lb" {
  source = "./elb"

  name = "${var.name}-alb"
  tags = var.tags
  vpc_id = var.vpc_id
  subnets_ids = local.lb_subnets_ids
  tipo = "application"
  internal_lb = var.internal_lb
  security_group = "${module.sg_ecs.sg_id}"
  tg_names = var.tg_names
  s3_certs = var.s3_certs
  http_rules = var.http_rules
  create_listener_https = var.create_listener_https
  certificate_arn = var.certificate_arn
  default_action_listener_http = var.default_action_listener_http
  default_action_listener_https = var.default_action_listener_https
}
*/

resource "aws_cloudwatch_log_group" "logs" {
  count = length(var.containers) > 0 ? length(var.containers) : 0
  name  = "/logs/ecs/${lookup(var.containers[count.index], "name", null)}/tsk-log"
  #name = "${var.layer}-${var.stack_id}-${lookup(var.tasks_definition[count.index], "name", null)}-tsk-log"
  retention_in_days = var.logs_retention_in_days
  tags  = merge(
  var.tags,
  { Name = var.name },
  )
}

module "role_service" {
  source = "./role"
  name = var.name
  region = var.region
  custom_policy = var.custom_policy
  policy_attachment = var.policy_attachment
}

module "task_definition" {
  source = "./task_definition"
  region = var.region

  containers = var.containers
  extra_template_variables = var.extra_template_variables
  tags = var.tags
  dns_lb = "${var.lb_dns_name}"
  ecs_task_role = "${module.role_service.ecs_task_role}"
  ecs_task_exec_role =  "${module.role_service.ecs_task_exec_role}"
  volumen_configuration = var.volumen_configuration
}


resource "aws_lb_target_group" "target_group" {
  count       = length(var.tg_names)
  name        = lookup(element(var.tg_names, count.index), "tg_name")
  port        = lookup(var.tg_names[count.index], "port", 80)
  protocol    = lookup(var.tg_names[count.index], "protocol", null) != null ? upper(lookup(var.tg_names[count.index], "protocol")) : "HTTP"
  vpc_id      = var.vpc_id
  target_type = lookup(var.tg_names[count.index], "target_type", "ip")

  dynamic "health_check" {
    for_each = length(keys(lookup(var.tg_names[count.index], "health_check", {}))) == 0 ? [] : [lookup(var.tg_names[count.index], "health_check", {})]

    content {
      path                = lookup(health_check.value, "path", null)
      port                = lookup(health_check.value, "port", "traffic-port")
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", 5)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", 2)
      timeout             = lookup(health_check.value, "timeout", 30)
      interval            = lookup(health_check.value, "interval", 60)
      protocol            = lookup(health_check.value, "protocol", null)
      matcher             = lookup(health_check.value, "matcher", 200)  # has to be HTTP 200 or fails
    }
  }
}

module "https_listener_rule" {
  source = "./elb/listener_rule"
  //count = length(var.http_rules) > 0 && ( var.create_listener_https || var.certificate_arn !=null) ? 1 : 0

  tags         = var.tags
  http_rules   = var.http_rules
  listener_arn = var.lb_listener_arn
  target_group = aws_lb_target_group.target_group.*.id
}
module "ecs_service" {
  source = "./ecs_service"

  name = var.name
  tags = var.tags
  layer = var.layer
  stack_id = var.stack_id
  containers = var.containers
  task_family = module.task_definition.family
  task_revison = module.task_definition.revision
  subnets = var.private_subnet_ids
  security_group = "${var.sg_id}"
  target_group_arns = aws_lb_target_group.target_group.*.arn
  ecs_cluster_id = var.ecs_cluster_id
  ecs_cluster_name = var.ecs_cluster_name
}

//output "cluster_id" { value = "${module.ecs_service.ecs_cluster_id}" }
//output "lb_dns_name" { value = "${module.lb.lb_dns_name}" }
//output "lb_arn" { value = "${module.lb.lb_arn}" }
//output "sg_id" { value = "${module.sg_ecs.sg_id}" }
//output "lb_listener_arn" { value = "${module.lb.lb_listener_arn}" }
//output "lb_listener_https_arn" { value = "${module.lb.lb_listener_https_arn}" }
//output "certificate_arn" { value = "${module.lb.certificate_arn}" }

/*output "certificate_body"  { value = module.lb.certificate_body}
output "certificate_key"   { value = module.lb.certificate_key }
output "certificate_chain" { value = module.lb.certificate_arn}*/
