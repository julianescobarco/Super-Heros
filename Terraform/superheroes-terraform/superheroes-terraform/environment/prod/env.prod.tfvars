#network
stack_id                  = "prod"
layer                     = "esuper-heroes"
type                      = "infra"
component_name            = "core"
region                    = "us-east-1"
vpc_cidr                  = "10.67.162.0/23"
private_subnet_cidr_block = ["10.67.162.0/25","10.67.162.128/25","10.67.163.0/25"]     # Creating one private subnet per AZ
public_subnet_cidr_block  = ["10.67.163.128/27","10.67.163.160/27","10.67.163.192/27"] # Creating one public subnet per AZ
azs                       = ["us-east-1a", "us-east-1b", "us-east-1c"]
tags                      = { "Source" = "Terraform", "type" = "infra", "environment" = "prod" }



# Variable Security Group ECS
ingress_rule = [
    {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    },
    {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    },
    {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
]

fargate_cpu = "256"
fargate_memory = "512"
hardLimit = "10240"
limitName = "nofile"
softLimit = "10240"


## Varables de acceso a base de datos
db_host                 = "superheroes-prod.cem4wpcywzd3.us-east-1.rds.amazonaws.com"
db_name                 = "superheroes"
db_limit_connections    = "10"
db_port                 = "3306"
db_user                 = "root"
db_password             = "root"
