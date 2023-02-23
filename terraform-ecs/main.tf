# Configure the AWS provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "EC2InternetGateway" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table" "EC2RouteTable" {
    vpc_id = aws_vpc.vpc.id
}

resource "aws_route_table_association" "rtb-association-1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.EC2RouteTable.id
}

resource "aws_route_table_association" "rtb-association-2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.EC2RouteTable.id
}



resource "aws_route" "EC2Route" {
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.EC2InternetGateway.id
    route_table_id = aws_route_table.EC2RouteTable.id
}

# Create the ECR repository
resource "aws_ecr_repository" "ecs-webapp" {
  name = "ecs-webapp"
}


# Create the ECS cluster
resource "aws_ecs_cluster" "ecs-webapp" {
  name = "ecs-webapp"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "ecs-task-execution-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "policy_attachment_AmazonEC2ContainerRegistryFullAccess" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

# Create the ECS task definition
resource "aws_ecs_task_definition" "ecs-webapp" {
  family                = "ecs-webapp"
  network_mode          = "awsvpc"
  cpu                   = 512
  memory                = 1024
  execution_role_arn    = aws_iam_role.ecs_task_execution_role.arn
  requires_compatibilities = ["FARGATE"]

  container_definitions = <<EOF
[
  {
    "name": "ecs-webapp",
    "image": "${aws_ecr_repository.ecs-webapp.repository_url}:latest",
    "cpu": 512,
    "memory": 1024,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 5000,
        "protocol": "tcp"
      }
    ]
  }
]
EOF
}


resource "aws_security_group" "ecs-webapp-alb-sg" {
  description = "for ecs alb"
  name = "ecs-webapp-alb-sg"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 80
    protocol = "tcp"
    to_port = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    protocol = "-1"
    to_port = 0
  }
}

resource "aws_alb" "webapp-alb" {
  name            = "webapp-alb"
  internal        = false
  security_groups = [aws_security_group.ecs-webapp-alb-sg.id]
  subnets         = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}

resource "aws_alb_target_group" "webapp-alb-tg" {
  name                = "webapp-alb-tg"
  port                = 5000
  protocol            = "HTTP"
  vpc_id              = aws_vpc.vpc.id
  target_type = "ip"
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-299"
  }
}

resource "aws_alb_listener" "webapp-alb-listener" {
  load_balancer_arn = aws_alb.webapp-alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.webapp-alb-tg.arn
    type             = "forward"
  }
}


resource "aws_security_group" "ecs_sg" {
  name        = "ecs_sg"
  description = "Security group for ECS service"
  vpc_id = aws_vpc.vpc.id
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    protocol = "-1"
    to_port = 0
  }  
}

# Create the ECS service
resource "aws_ecs_service" "ecs-fargate-service" {
    name = "ecs-fargate-service"
    cluster = "${aws_ecs_cluster.ecs-webapp.id}"
    load_balancer {
      target_group_arn = aws_alb_target_group.webapp-alb-tg.id
      container_name = "ecs-webapp"
      container_port = 5000
    }
    desired_count = 1
    launch_type = "FARGATE"
    platform_version = "LATEST"
    task_definition = "${aws_ecs_task_definition.ecs-webapp.arn}"
    deployment_maximum_percent = 200
    deployment_minimum_healthy_percent = 100
    network_configuration {
        assign_public_ip = true
        security_groups = [aws_security_group.ecs_sg.id]
        subnets = [aws_subnet.public_1.id, aws_subnet.public_2.id]
    }
    scheduling_strategy = "REPLICA"
}

resource "aws_appautoscaling_target" "ecs-webapp-asg-tg" {
  service_namespace = "ecs"
  resource_id       = "service/${aws_ecs_cluster.ecs-webapp.name}/${aws_ecs_service.ecs-fargate-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity      = 1
  max_capacity      = 3
}


resource "aws_appautoscaling_policy" "ecs-webapp-asg" {
  name               = "ecs-webapp-asg"
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.ecs-webapp.name}/${aws_ecs_service.ecs-fargate-service.name}"
  scalable_dimension  = "ecs:service:DesiredCount"
  policy_type        = "TargetTrackingScaling"
  target_tracking_scaling_policy_configuration {
    target_value = 70
    scale_in_cooldown = 60
    scale_out_cooldown = 60
    disable_scale_in = false
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

