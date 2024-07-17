#ID Cuenta
data "aws_caller_identity" "current" {}

#Varibles locales
locals {  
    #Variables Cluster ECS_Integration
    tg_names_integration = [
        {
            tg_name  = "${var.layer}-${var.stack_id}-tg"
            protocol = "HTTP"
            port     = 80
            health_check = {
                path = "/superheroes/health"
                timeout  = 30
            }
        }
    ]


    http_rules_integration = [
        {
            actions = [
                {
                    type               = "forward"
                    target_group_index = 1
                }
            ]
            conditions = [
                {
                    path_patterns = ["/*"]
                }
            ]
        }
    ]


    containers_integration = [
        {
            name                  = "${var.layer}-${var.stack_id}-service"
            family                = "${var.layer}-${var.stack_id}-ms-java-fargate-task"
            min_size              = 2
            max_size              = 10
            desired_count         = 1
            cpu                   = 512
            memory                = 1024
            network_mode          = "awsvpc"
            container_definitions = "./container_definition_integration/definitionAlly.json"
            load_balancers = [
                {
                    target_group_arn = 0
                    container_name   = "${var.layer}-${var.stack_id}-ms-java-fargate"
                    container_port   = 80
                }
            ]
        }
    ]

    extra_template_variables_integration = {
        "stack_id" : "${var.stack_id}"
        "layer" : "${var.layer}"
        "task_cpu" : "${var.fargate_cpu}",
        "task_memory" : "${var.fargate_memory}",
        "region" : "${var.region}",
        "hardLimit" : "${var.hardLimit}",
        "limitName" : "${var.limitName}",
        "softLimit" : "${var.softLimit}",
        "account_id" : "${data.aws_caller_identity.current.account_id}",
        "db_host" : "${var.db_host}",
        "db_port" : "${var.db_port}",
        "db_name" : "${var.db_name}",
        "db_limit_connections" : "${var.db_limit_connections}"

    }   


}