data "aws_ssm_parameter" "latest_optimized_ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_lb" "example" {
  name                       = "example"
  internal                   = false
  load_balancer_type         = "application"
  drop_invalid_header_fields = true

  security_groups = [
    aws_security_group.example_ecs.id
  ]

  subnets = [
    aws_subnet.example_a.id,
    aws_subnet.example_b.id,
    aws_subnet.example_c.id
  ]

  tags = {
    Name  = "tf-alb-example"
    Owner = "John Ajera"
  }
}

resource "aws_lb_target_group" "example" {
  name     = "example"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.example.id

  health_check {
    enabled             = true
    healthy_threshold   = 5
    unhealthy_threshold = 2
    path                = "/"
  }

  tags = {
    Name  = "tf-alb-tg-example"
    Owner = "John Ajera"
  }
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }

  tags = {
    Name  = "tf-alb-listener-example"
    Owner = "John Ajera"
  }
}

resource "aws_iam_role" "ecs_assume" {
  name = "ecs-assume"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Sid": "EC2AssumeRole"
    }
  ]
}
EOF

  tags = {
    Name  = "tf-iam-role-ec2-assume-example"
    Owner = "John Ajera"
  }
}


resource "aws_iam_policy" "ecs_assume" {
  name        = "ecs-assume"
  description = "Policy for ECS and ECR"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeContainerInstances",
        "ecs:DeregisterContainerInstance",
        "ecs:ListClusters",
        "ecs:ListContainerInstances",
        "ecs:ListServices",
        "ecs:ListTagsForResource",
        "ecs:Poll",
        "ecs:RegisterContainerInstance",
        "ecs:StartTelemetrySession",
        "ecs:Submit*",
        "ecs:UpdateContainerInstancesState"
      ],
      "Resource": "arn:aws:ecs:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecs:DiscoverPollEndpoint",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:DescribeLogStreams",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_attachment" {
  policy_arn = aws_iam_policy.ecs_assume.arn
  role       = aws_iam_role.ecs_assume.name
}

resource "aws_iam_instance_profile" "ecs_assume" {
  name = "ecs-assume"
  role = aws_iam_role.ecs_assume.name

  tags = {
    Name  = "tf-iam-ec2-assume"
    Owner = "John Ajera"
  }
}

resource "aws_launch_template" "example" {
  name_prefix   = "lt-example-"
  ebs_optimized = true
  image_id      = data.aws_ssm_parameter.latest_optimized_ecs_ami.value
  instance_type = "t3.micro"
  key_name      = aws_key_pair.example.key_name

  vpc_security_group_ids = [
    aws_security_group.example_ecs.id
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_assume.name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 30
      volume_type = "gp2"
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name  = "tf-lt-example"
      Owner = "John Ajera"
    }
  }

  user_data = filebase64("${path.module}/external/ecs.sh")
}

resource "aws_autoscaling_group" "example" {
  name = "example"

  vpc_zone_identifier = [
    aws_subnet.example_a.id,
    aws_subnet.example_b.id,
    aws_subnet.example_c.id
  ]

  max_size                  = 6
  min_size                  = 1
  desired_capacity          = 3
  health_check_type         = "EC2"
  health_check_grace_period = 0

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]

  termination_policies = [
    "AllocationStrategy",
    "OldestLaunchTemplate",
    "ClosestToNextInstanceHour",
    "Default"
  ]

  protect_from_scale_in = true
  max_instance_lifetime = 86400
  # force_delete              = true
  # wait_for_capacity_timeout = "1m"

  launch_template {
    name    = aws_launch_template.example.name
    version = aws_launch_template.example.latest_version
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_capacity
    ]
  }

  tag {
    key                 = "Name"
    value               = "ecs-example"
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = "John Ajera"
    propagate_at_launch = true
  }

  tag {
    key                 = "amazon-ecs-managed"
    value               = true
    propagate_at_launch = true
  }
}
