#--------------------------------------------------------------
# Este modulo crea los recursos necesarios para crear Autoscalling Group
#--------------------------------------------------------------

variable "containers" {}
variable "ecs_cluster" {}

variable "layer" {
  type    = string
  default = ""
}

variable "stack_id" {
  type    = string
  default = ""
}

variable "use_target_tracking_scaling" {
  type    = bool
  default = true
}

locals {
  cpu_utilization    = 45
  memory_utilization = 70
  cooldown_period    = 60

}

resource "aws_appautoscaling_target" "main" {
  count = length(var.containers) > 0 ? length(var.containers) : 0

  max_capacity       = lookup(var.containers[count.index], "max_size", null)
  min_capacity       = lookup(var.containers[count.index], "min_size", null)
  resource_id        = "service/${var.ecs_cluster}/${lookup(var.containers[count.index], "name", null)}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


#use Target Tracking Scaling
resource "aws_appautoscaling_policy" "ecs_policies_memory" {
  count              = var.use_target_tracking_scaling ? length(var.containers) : 0
  name               = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-memory-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = element(aws_appautoscaling_target.main.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.main.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.main.*.service_namespace, count.index)

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    scale_in_cooldown  = local.cooldown_period
    scale_out_cooldown = local.cooldown_period
    disable_scale_in   = false

    target_value = local.memory_utilization
  }
}

resource "aws_appautoscaling_policy" "ecs_policies_cpu" {
  count              = var.use_target_tracking_scaling ? length(var.containers) : 0
  name               =  "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-cpu1-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = element(aws_appautoscaling_target.main.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.main.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.main.*.service_namespace, count.index)

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    scale_in_cooldown  = local.cooldown_period
    scale_out_cooldown = local.cooldown_period
    disable_scale_in   = false

    target_value = local.cpu_utilization
  }
}

#CloudWatch Alarms

resource "aws_cloudwatch_metric_alarm" "alarms_cpu_more" {
  count               = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  alarm_name          = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-ecs-alarmCpuMore"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = local.cpu_utilization

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cpu_policies_up[count.index].arn]
  dimensions = {
    "ClusterName" = var.ecs_cluster
    "ServiceName" = "${lookup(var.containers[count.index], "name", null)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "alarms_cpu_less" {
  count               = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  alarm_name          = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-ecs-alarmCpuLess"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = local.cpu_utilization

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_appautoscaling_policy.ecs_cpu_policies_down[count.index].arn]
  dimensions = {
    "ClusterName" = var.ecs_cluster
    "ServiceName" = "${lookup(var.containers[count.index], "name", null)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_memory_more" {
  count               = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  alarm_name          = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-ecs-alarmMemoryMore"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = local.memory_utilization

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_appautoscaling_policy.ecs_memory_policies_up[count.index].arn]
  dimensions = {
    "ClusterName" = var.ecs_cluster
    "ServiceName" = "${lookup(var.containers[count.index], "name", null)}"
  }
}

resource "aws_cloudwatch_metric_alarm" "alarm_memory_less" {
  count               = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  alarm_name          = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-ecs-alarmMemoryLess"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Average"
  threshold           = local.memory_utilization

  alarm_description = "This metric monitors ec2 cpu utilization"
  alarm_actions     = [aws_appautoscaling_policy.ecs_memory_policies_down[count.index].arn]
  dimensions = {
    "ClusterName" = var.ecs_cluster
    "ServiceName" = "${lookup(var.containers[count.index], "name", null)}"
  }
}

# Step Scaling
resource "aws_appautoscaling_policy" "ecs_cpu_policies_up" {
  count              = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  name               = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-scaling-up-CpuPolicy"
  policy_type        = "StepScaling"
  resource_id        = element(aws_appautoscaling_target.main.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.main.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.main.*.service_namespace, count.index)
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = local.cooldown_period
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_cpu_policies_down" {
  count              = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  name               = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-scaling-in-CpuPolicy"
  policy_type        = "StepScaling"
  resource_id        = element(aws_appautoscaling_target.main.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.main.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.main.*.service_namespace, count.index)

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = local.cooldown_period
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policies_up" {
  count              = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  name               = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-scaling-up-MemoryPolicy"
  policy_type        = "StepScaling"
  resource_id        = element(aws_appautoscaling_target.main.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.main.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.main.*.service_namespace, count.index)

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = local.cooldown_period
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policies_down" {
  count              = ! var.use_target_tracking_scaling ? length(var.containers) : 0
  name               = "${var.layer != "" ? format("%s-", var.layer) : ""}${var.stack_id != "" ? format("%s-", var.stack_id) : ""}${lookup(var.containers[count.index], "name", null)}-scaling-in-MemoryPolicy"
  policy_type        = "StepScaling"
  resource_id        = element(aws_appautoscaling_target.main.*.resource_id, count.index)
  scalable_dimension = element(aws_appautoscaling_target.main.*.scalable_dimension, count.index)
  service_namespace  = element(aws_appautoscaling_target.main.*.service_namespace, count.index)

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = local.cooldown_period
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

#add policy autoscaling
#minimo 2 tareas y maximo 10
#Minimum tasks: 2Maximum tasks: 10
#CPU: Tracking ECSServiceAverageCPUUtilization at 45
#Policy type: Target tracking
#Disable Scale In: false
#Memory: MemoryUtilization >= 70
#Policy type: Step scaling
#For alarm: 
#Take the action:
#Add 1 tasks when 70 <= MemoryUtilization < 85
#Add 1 tasks when 85 <= MemoryUtilization < 95
#Add 1 tasks when 95 <= MemoryUtilization
