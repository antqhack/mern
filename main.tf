variable "aws_access_key" {
	type = string
}
variable "aws_secret_key" {
	type = string
}

terraform {
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = "4.45.0"
		}
	}
}


provider "aws" {
	region = "us-east-2"
	access_key = var.aws_access_key 
	secret_key = var.aws_secret_key
}

resource "aws_ecr_repository" "app_ecr_repo" {
	name = "app-repo"
}

resource "aws_ecs_cluster" "my_cluster" {
	name = "app-cluster"
}

# --- ECS Node Role ---

data "aws_iam_policy_document" "ecs_node_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_node_role" {
  name_prefix        = "demo-ecs-node-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_node_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_node_role_policy" {
  role       = aws_iam_role.ecs_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_node" {
  name_prefix = "demo-ecs-node-profile"
  path        = "/ecs/instance/"
  role        = aws_iam_role.ecs_node_role.name
}

resource "aws_security_group" "ecs_node_sg" {
  name_prefix = "demo-ecs-node-sg-"

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- ECS Launch Template ---

data "aws_ssm_parameter" "ecs_node_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "ecs_ec2" {
  name_prefix            = "demo-ecs-ec2-"
  image_id               = data.aws_ssm_parameter.ecs_node_ami.value
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.ecs_node_sg.id]

  iam_instance_profile { arn = aws_iam_instance_profile.ecs_node.arn }
  monitoring { enabled = true }

  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.my_cluster.name} >> /etc/ecs/ecs.config;
    EOF
  )
}

# --- ECS ASG ---

resource "aws_autoscaling_group" "ecs" {
  name_prefix               = "demo-ecs-asg-"
  min_size                  = 2
  max_size                  = 8
  health_check_grace_period = 0
  availability_zones = ["us-east-2a", "us-east-2b"]
  health_check_type         = "EC2"
  protect_from_scale_in     = false

  launch_template {
    id      = aws_launch_template.ecs_ec2.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "demo-ecs-cluster"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }
}


# --- ECS Capacity Provider ---

resource "aws_ecs_capacity_provider" "main" {
  name = "demo-ecs-ec2"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.my_cluster.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    base              = 1
    weight            = 100
  }
}

resource "aws_ecs_task_definition" "app_task" {
	family			= "app-first-task"
	container_definitions	= <<DEFINITION
	[
		{
			"name": "app-first-task",
			"image": "${aws_ecr_repository.app_ecr_repo.repository_url}",
			"essential": true,
			"portMappings": [
				{
					"containerPort": 5000,
					"hostPort": 5000
				}
			],
			"memory": 512,
			"cpu": 256
		}
	]
	DEFINITION
	requires_compatibilities 	= ["EC2"]
	network_mode 			= "awsvpc"
	memory				= 512
	cpu				= 256
	execution_role_arn 		= "${aws_iam_role.ecsTaskExecutionRole.arn}"
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
	name			= "ecwTaskExecutionRole"
	assume_role_policy 	= "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
	statement {
		actions = ["sts:AssumeRole"]

		principals {
			type		= "Service"
			identifiers	= ["ecs-tasks.amazonaws.com"]
		}
	}
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
	role		= "${aws_iam_role.ecsTaskExecutionRole.name}"
	policy_arn	= "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_default_vpc" "default_vpc" {
}

resource "aws_default_subnet" "default_subnet_a" {
	availability_zone = "us-east-2a"
}

resource "aws_default_subnet" "default_subnet_b" {
	availability_zone = "us-east-2b"
}

resource "aws_alb" "application_load_balancer" {
	name			= "load-balancer-dev"
	load_balancer_type	= "application"
	subnets = [
		"${aws_default_subnet.default_subnet_a.id}",
		"${aws_default_subnet.default_subnet_b.id}"
	]
	
	security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

resource "aws_security_group" "load_balancer_security_group" {
	ingress {
		from_port	= 80
		to_port		= 80
		protocol	= "tcp"
		cidr_blocks	= ["0.0.0.0/0"]
	}

	egress {
		from_port 	= 0
		to_port 	= 0
		protocol	= "-1"
		cidr_blocks	= ["0.0.0.0/0"]
	}
}

resource "aws_lb_target_group" "target_group" {
	name		= "target-group"
	port		= 80
	protocol	= "HTTP"
	target_type	= "ip"
	vpc_id		="${aws_default_vpc.default_vpc.id}"
}

resource "aws_lb_listener" "listener" {
	load_balancer_arn 	= "${aws_alb.application_load_balancer.arn}"
	port			= "80"
	protocol		= "HTTP"
	default_action	{
		type 		= "forward"
		target_group_arn = "${aws_lb_target_group.target_group.arn}"
	}
}

resource "aws_ecs_service" "app_service" {
	name		= "app-first-service"
	cluster		= "${aws_ecs_cluster.my_cluster.id}"
	task_definition	= "${aws_ecs_task_definition.app_task.arn}"
	launch_type	= "EC2"
	desired_count	= 3

	load_balancer {
		target_group_arn	= "${aws_lb_target_group.target_group.arn}"
		container_name		= "${aws_ecs_task_definition.app_task.family}"
		container_port		= 5000
	}
	
	network_configuration {
		subnets			= ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
		security_groups		= ["${aws_security_group.service_security_group.id}"]
		
	}
}

resource "aws_security_group" "service_security_group" {
	ingress {
		from_port 	= 0
		to_port		= 0
		protocol	= "-1"
		security_groups	= ["${aws_security_group.load_balancer_security_group.id}"]
	}

	egress {
		from_port	= 0
		to_port		= 0
		protocol	= "-1"
		cidr_blocks	= ["0.0.0.0/0"]
	}
}

output "app_url" {
	value = aws_alb.application_load_balancer.dns_name
}
