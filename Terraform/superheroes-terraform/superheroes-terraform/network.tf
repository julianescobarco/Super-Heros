# Create network
module "network" {
    source             = "./modules/network"
    name               = "${var.layer}-${var.stack_id}"
    vpc_cidr           = var.vpc_cidr
    stack_id           = var.stack_id
    layer              = var.layer
    tags               = var.tags
    azs                = var.azs
    private_subnets    = var.private_subnet_cidr_block
    public_subnets     = var.public_subnet_cidr_block
}