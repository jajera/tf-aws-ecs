resource "aws_ecs_task_definition" "webapp" {
  family                   = "webapp-${random_string.suffix.result}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]

  container_definitions = jsonencode([{
    name   = "nginx"
    image  = "public.ecr.aws/nginx/nginx:stable-perl"
    cpu    = 256
    memory = 512

    essential = true

    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]

    mountPoints = [{
      sourceVolume  = "html-volume"
      containerPath = "/usr/share/nginx/html"
    }]

    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-create-group"  = "True",
        "awslogs-group"         = "/ecs-${random_string.suffix.result}/ecs/service/webapp",
        "awslogs-region"        = "${data.aws_region.current.name}",
        "awslogs-stream-prefix" = "replica",
      }
    },
  }])

  volume {
    name = "html-volume"
  }
}

resource "aws_ecs_service" "webapp" {
  name                = "webapp"
  cluster             = aws_ecs_cluster.example.id
  launch_type         = "EC2"
  propagate_tags      = "TASK_DEFINITION"
  scheduling_strategy = "REPLICA"
  task_definition     = aws_ecs_task_definition.webapp.arn

  enable_ecs_managed_tags = true
  desired_count           = 1

  deployment_controller {
    type = "ECS"
  }

  load_balancer {
    target_group_arn = aws_lb_listener.webapp.default_action[0].target_group_arn
    container_name   = "nginx"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [
      desired_count,
    ]
  }
}

resource "aws_appautoscaling_target" "webapp" {
  max_capacity       = 6
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.example.name}/${aws_ecs_service.webapp.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "webapp_up" {
  name               = "webapp_up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.webapp.resource_id
  scalable_dimension = aws_appautoscaling_target.webapp.scalable_dimension
  service_namespace  = aws_appautoscaling_target.webapp.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }
}

resource "aws_appautoscaling_policy" "webapp_down" {
  name               = "webapp_down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.webapp.resource_id
  scalable_dimension = aws_appautoscaling_target.webapp.scalable_dimension
  service_namespace  = aws_appautoscaling_target.webapp.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = -1
    }
  }
}
