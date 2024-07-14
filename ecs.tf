
resource "aws_ecs_cluster" "example" {
  name = "private-${random_string.suffix.result}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      logging = "OVERRIDE"

      log_configuration {
        cloud_watch_log_group_name = aws_cloudwatch_log_group.private.name
      }
    }
  }
}

resource "aws_ecs_capacity_provider" "example" {
  name = "private-${random_string.suffix.result}"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.example.arn

    managed_scaling {
      maximum_scaling_step_size = 1
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name = "private-${random_string.suffix.result}"
  }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.example.name

  capacity_providers = [
    aws_ecs_capacity_provider.example.name
  ]

  default_capacity_provider_strategy {
    weight            = 1
    capacity_provider = aws_ecs_capacity_provider.example.name
  }
}
