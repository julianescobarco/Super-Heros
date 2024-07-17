#--------------------------------------------------------------
# Estos modulos crea los recursos necesarios para el alb
#--------------------------------------------------------------

variable "name"                 { default = "lb" }
variable "tags"                 { }
variable "vpc_id"               { }
variable "subnets_ids"          { }
variable "tipo"                 { }
variable "security_group"       { }
variable "http_rules"           { }
variable "create_listener_https"{ }
variable "s3_certs"             { }
variable "tg_names"             { }
variable "internal_lb"          { }
variable "certificate_arn"      { }

variable "default_action_listener_http" {}

variable "default_action_listener_https" {}

locals {
  certificate_arn   = var.certificate_arn != null ?  var.certificate_arn : (var.create_listener_https ? aws_acm_certificate.cert[0].arn : null)

  lb_default_action_http = {
    type               = try(var.default_action_listener_http.type, "fixed-response")
    target_group_index = try(var.default_action_listener_http.target_group_index, -1)
    redirect           = try(var.default_action_listener_http.redirect, [])
    fixed_response     = try(var.default_action_listener_http.fixed_response, [{status_code  = "404"
      content_type = "text/plain"
      message_body = "Pagina no encontrada"
    }])
  }

  lb_default_action_https = {
    type               = try(var.default_action_listener_https.type, "fixed-response")
    target_group_index = try(var.default_action_listener_https.target_group_index, -1)
    redirect           = try(var.default_action_listener_https.redirect, [])
    fixed_response     = try(var.default_action_listener_https.fixed_response, [{status_code  = "404"
      content_type = "text/plain"
      message_body = "Pagina no encontrada"
    }])
  }

}

resource "aws_lb" "lb" {
  name               = var.name
  internal           = var.internal_lb
  load_balancer_type = var.tipo
  subnets            = var.subnets_ids
  security_groups    = var.security_group

  enable_cross_zone_load_balancing = true

  tags  = merge(
  var.tags,
  { Name = var.name },
  )
}

data "aws_s3_bucket_object" "private_key" {
  count = var.create_listener_https ? 1 : 0
  bucket = var.s3_certs
  key    = "private_key.pem"
}

data "aws_s3_bucket_object" "certificate_body" {
  count = var.create_listener_https ? 1 : 0
  bucket = var.s3_certs
  key    = "certificate_body.pem"
}

data "aws_s3_bucket_object" "certificate_chain" {
  count = var.create_listener_https ? 1 : 0
  bucket = var.s3_certs
  key    = "certificate_chain.pem"
}

resource "aws_acm_certificate" "cert" {
  count = var.create_listener_https ? 1 : 0

  tags  = merge(
  var.tags,
  { Name = var.name },
  )

  lifecycle {
    create_before_destroy = true
  }

  certificate_body = data.aws_s3_bucket_object.certificate_body[count.index].body
  private_key      = data.aws_s3_bucket_object.private_key[count.index].body
  certificate_chain = data.aws_s3_bucket_object.certificate_chain[count.index].body
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

  dynamic "stickiness" {
    for_each = length(keys(lookup(var.tg_names[count.index], "stickiness", {}))) == 0 ? [] : [lookup(var.tg_names[count.index], "stickiness", {})]

    content {
      type            = lookup(stickiness.value, "type", "lb_cookie")
      enabled         = lookup(stickiness.value, "enabled", true)
      cookie_duration = lookup(stickiness.value, "cookie_duration", 86400)
    }
  }
}


# Redirect all traffic from the LB to the target group
resource "aws_lb_listener" "listener_http" {
  load_balancer_arn =  aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = local.lb_default_action_http.type
    target_group_arn = local.lb_default_action_http.target_group_index >= 0 ? aws_lb_target_group.target_group[local.lb_default_action_http.target_group_index].id : null

    # redirect actions
    dynamic "redirect" {
      for_each = local.lb_default_action_http.redirect

      content {
        host        = lookup(redirect.value, "host", null)
        path        = lookup(redirect.value, "path", null)
        port        = lookup(redirect.value, "port", null)
        protocol    = lookup(redirect.value, "protocol", null)
        query       = lookup(redirect.value, "query", null)
        status_code = redirect.value["status_code"]
      }
    }

    ## fixed-response actions
    dynamic "fixed_response" {
      for_each =  local.lb_default_action_http.fixed_response
      content {
        message_body = lookup(fixed_response.value,"message_body", null)
        status_code  = lookup(fixed_response.value,"status_code", null)
        content_type = fixed_response.value.content_type
      }
    }

  }
}


resource "aws_lb_listener" "listener_https" {
  count = var.create_listener_https || var.certificate_arn !=null ? 1 : 0
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = local.lb_default_action_https.type
    target_group_arn = local.lb_default_action_https.target_group_index >= 0 ? aws_lb_target_group.target_group[local.lb_default_action_https.target_group_index].id : null

    # redirect actions
    dynamic "redirect" {
      for_each = local.lb_default_action_https.redirect

      content {
        host        = lookup(redirect.value, "host", null)
        path        = lookup(redirect.value, "path", null)
        port        = lookup(redirect.value, "port", null)
        protocol    = lookup(redirect.value, "protocol", null)
        query       = lookup(redirect.value, "query", null)
        status_code = redirect.value["status_code"]
      }
    }

    ## fixed-response actions
    dynamic "fixed_response" {
      for_each =  local.lb_default_action_https.fixed_response
      content {
        message_body = lookup(fixed_response.value,"message_body", null)
        status_code  = lookup(fixed_response.value,"status_code", null)
        content_type = fixed_response.value.content_type
      }
    }

  }
}

module "https_listener_rule" {
  source = "./listener_rule"
  count = length(var.http_rules) > 0 && ( var.create_listener_https || var.certificate_arn !=null) ? 1 : 0

  tags         = var.tags
  http_rules   = var.http_rules
  listener_arn = aws_lb_listener.listener_https[0].arn
  target_group = aws_lb_target_group.target_group.*.id
}

module "http_listener_rule" {
  source = "./listener_rule"
  count = length(var.http_rules) > 0 ? 1 : 0

  tags         = var.tags
  http_rules   = var.http_rules
  listener_arn = aws_lb_listener.listener_http.arn
  target_group = aws_lb_target_group.target_group.*.id
}

output "lb_name" { value = "${aws_lb.lb.name}" }
output "lb_arn" { value = "${aws_lb.lb.arn}" }
output "lb_dns_name" { value = "${aws_lb.lb.dns_name}" }
output "lb_listener_arn" { value = "${aws_lb_listener.listener_http.arn}" }
output "lb_listener_https_arn" { value =  var.create_listener_https ? "${aws_lb_listener.listener_https[0].arn}" : null  }
output "target_group_arns" {
  description = "ARNs of the target groups. Useful for passing to your Auto Scaling group."
  value       = aws_lb_target_group.target_group.*.arn
}
output "certificate_arn" { value =  var.create_listener_https || var.certificate_arn !=null ? local.certificate_arn : null  }

/*output "certificate_body" {
  value = data.aws_s3_bucket_object.certificate_body[0].body
}

output "certificate_key" {
  value = data.aws_s3_bucket_object.private_key[0].body
}
output "certificate_chain" {
}*/