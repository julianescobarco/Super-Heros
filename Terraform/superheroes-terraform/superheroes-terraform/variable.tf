# network
variable "stack_id" {
  description = "Nombre del ambiente"
  type        = string
}

variable "layer" {
  description = "Nombre del proyecto"
  type        = string
}

variable "type" {
  description = "Tipo del recurso, infra, frontend, movil, backend"
  type        = string
}

variable "component_name" {
  description = "Nombre del componente"
  type        = string
}

variable "region" {
  default = "us-east-1"
}

variable "tags" {
  description = "Nombre del proyecto"
  type        = map(any)
}

variable "azs" {
}

variable "vpc_cidr" {
  description = "CIDR vpc connection red"
  type        = string
}

variable "private_subnet_cidr_block" {
}
variable "public_subnet_cidr_block" {
}

variable  "ingress_rules_api" {
  description = "Ingres rules for security group in apigateway"
  type = list(object({from_port = string, to_port= string, protocol = string, cidr_blocks = list(string)}))
  default = [ {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  } ]
}



variable "ingress_rule"              {}
variable "fargate_cpu"               {}
variable "fargate_memory"            {}
variable "hardLimit"                 {}
variable "limitName"                 {}
variable "softLimit"                 {}



variable "db_host" {
  type = string
  description = "Host base de datos" 
}

variable "db_name" {
  type = string
  description = "Nombre de base de datos" 
}

variable "db_port" {
  type = number
  description = "Puerto de conexión a base de datos" 
}

variable "db_limit_connections" {
  type = number
  description = "Limite de conexiones de base de datos"
}

variable "db_user" {
  type = string
  description = "Usuario conexión de base de datos" 
}

variable "db_password" {
  type = string
  description = "Contraseña para ingreso de base de datos" 
}
