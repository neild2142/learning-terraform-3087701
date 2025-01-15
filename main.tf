# # Find the latest available AMI that is tagged with the bitnami-tomcat-*-x86_64-hvm-ebs-nami name
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

data "aws_vpc" "default" {
  default = true
}

# Dev VPC
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs            = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type

  subnet_id = module.blog_vpc.public_subnets[0]

  associate_public_ip_address = true

  tags = {
    Name = "HelloWorld"
  }

  vpc_security_group_ids = [module.blog_sg.security_group_id]
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets
  security_groups = module.blog_sg.security_group_id

  # Security Group
  security_group_ingress_rules = {
    all_http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP web traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "10.0.0.0/16"
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
    }
  }

  target_groups = {
    ex-instance = {
      name_prefix      = "h1"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = aws_instance.blog.id
    }
  }

  tags = {
    Environment = "dev"
  }
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name    = "blog"

  vpc_id = module.blog_vpc.vpc_id

  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
