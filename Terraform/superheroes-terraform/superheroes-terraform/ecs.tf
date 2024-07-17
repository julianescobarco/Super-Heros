
module "superheroies_services" {
    source             = "./modules/ecs"
    name = "${var.layer}-${var.stack_id}"
    region = var.region
    stack_id           = var.stack_id
    layer              = var.layer
    tags               = var.tags
    vpc_id = module.network.vpc_id
    subnets = module.network.private_subnet_cidr_block
    private_subnet_ids = module.network.private_subnet_ids
    ingress_rule = var.ingress_rule
    tg_names = local.tg_names_integration
    http_rules = local.http_rules_integration
    containers = local.containers_integration
    extra_template_variables = local.extra_template_variables_integration
    lb_dns_name = module.ecs_cluster_integration_services.lb_dns_name
    sg_id = module.ecs_cluster_integration_services.sg_id
    lb_listener_arn = module.ecs_cluster_integration_services.lb_listener_arn
    ecs_cluster_id = module.ecs_cluster_integration_services.cluster_id
    ecs_cluster_name = "${var.layer}-${var.stack_id}-ecs-cluster"
}