data "aws_ssm_parameter" "latest_optimized_ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

resource "aws_launch_template" "example" {
  name_prefix   = "private-${random_string.suffix.result}-"
  ebs_optimized = true
  image_id      = data.aws_ssm_parameter.latest_optimized_ecs_ami.value
  instance_type = "t3.micro"
  key_name      = aws_key_pair.example.key_name

  vpc_security_group_ids = [
    aws_security_group.container.id,
    aws_security_group.ssh_internal.id, # for testing
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_assume.name
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
      Name = "private"
    }
  }

  user_data = base64encode(templatefile("${path.module}/external/ecs.sh.tpl", {
    cluster_name = aws_ecs_cluster.example.name
  }))
}

resource "aws_autoscaling_group" "example" {
  name = "private-${random_string.suffix.result}"

  vpc_zone_identifier = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
    aws_subnet.private_c.id
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
      desired_capacity,
      tag
    ]
  }

  tag {
    key                 = "Name"
    value               = "private-${random_string.suffix.result}"
    propagate_at_launch = true
  }

  tag {
    key                 = "amazon-ecs-managed"
    value               = true
    propagate_at_launch = true
  }
}
