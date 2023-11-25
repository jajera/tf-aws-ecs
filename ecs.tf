
resource "aws_ecs_cluster" "example" {
  name = "example"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name  = "tf-ecs-cluster-example"
    Owner = "John Ajera"
  }
}

resource "aws_ecs_capacity_provider" "example" {
  name = "example1"

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
    Name  = "tf-ecs-capacity-provider-example"
    Owner = "John Ajera"
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

data "aws_iam_policy_document" "ecs_task_assume" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "cwagent_task" {
  name               = "CWAgentECSTaskRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = {
    Name  = "tf-iam-role-cwagent-task-example"
    Owner = "John Ajera"
  }
}

resource "aws_iam_role_policy_attachment" "cwagent_task_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cwagent_task.name
}

resource "aws_iam_role" "cwagent_execution" {
  name               = "CWAgentECSExecutionRole"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "cwagent_ssm_read_policy" {
  role       = aws_iam_role.cwagent_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cwagent_cw_server_policy" {
  role       = aws_iam_role.cwagent_execution.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "cwagent_ecs_task_exec_policy" {
  role       = aws_iam_role.cwagent_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "cwagent" {
  name              = "example"
  retention_in_days = 1

  tags = {
    Name  = "tf-cw-log-group-cwagent"
    Owner = "John Ajera"
  }
}

resource "aws_ssm_parameter" "cwagent" {
  name        = "cwagent-config-example"
  description = "CloudWatch agent config for example cluster instances"
  type        = "String"
  value = jsonencode(
    {
      "agent" : {
        "metrics_collection_interval" : 60
      },
      "logs" : {
        "metrics_collected" : {
          "ecs" : {
            "metrics_collection_interval" : 30
          }
        },
        "logs_collected" : {
          "files" : {
            "collect_list" : [
              {
                "file_path" : "/var/log/ecs/ecs-agent.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-agent",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/ecs/ecs-init.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-init",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/ecs/audit.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/ecs-audit",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/messages",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/messages",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/secure",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/secure",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/auth.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/auth",
                "timezone" : "UTC"
              },
              {
                "file_path" : "/var/log/amazon/efs/mount.log",
                "log_group_name" : "example",
                "log_stream_name" : "{instance_id}/mount.log",
                "timezone" : "UTC"
              }
            ]
          }
        },
        "force_flush_interval" : 15
      }
    }
  )

  tags = {
    Name  = "tf-ssm-parameter-cwagent-example"
    Owner = "John Ajera"
  }
}

resource "aws_ecs_task_definition" "cwagent" {
  cpu                      = 128
  memory                   = 256
  family                   = "cwagent-example"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.cwagent_task.arn
  execution_role_arn       = aws_iam_role.cwagent_execution.arn

  volume {
    name      = "proc"
    host_path = "/proc"
  }

  volume {
    name      = "dev"
    host_path = "/dev"
  }

  volume {
    name      = "host_logs"
    host_path = "/var/log"
  }

  volume {
    name      = "al1_cgroup"
    host_path = "/cgroup"
  }

  volume {
    name      = "al2_cgroup"
    host_path = "/sys/fs/cgroup"
  }

  container_definitions = jsonencode([{
    name   = "cloudwatch-agent"
    image  = "amazon/cloudwatch-agent:latest"
    cpu    = 128
    memory = 256

    mountPoints = [
      {
        readOnly      = true,
        containerPath = "/rootfs/proc",
        sourceVolume  = "proc",
      },
      {
        readOnly      = true,
        containerPath = "/rootfs/dev",
        sourceVolume  = "dev",
      },
      {
        readOnly      = true,
        containerPath = "/sys/fs/cgroup",
        sourceVolume  = "al2_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/cgroup",
        sourceVolume  = "al1_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/rootfs/sys/fs/cgroup",
        sourceVolume  = "al2_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/rootfs/cgroup",
        sourceVolume  = "al1_cgroup",
      },
      {
        readOnly      = true,
        containerPath = "/var/log",
        sourceVolume  = "host_logs",
      },
    ],

    secrets = [
      {
        name      = "CW_CONFIG_CONTENT",
        valueFrom = "cwagent-config-example",
      },
    ],

    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-create-group"  = "True",
        "awslogs-group"         = "cwagent",
        "awslogs-region"        = "ap-southeast-1",
        "awslogs-stream-prefix" = "daemon",
      }
    },
  }])

  tags = {
    Name  = "tf-ecs-task-definition-cwagent-example"
    Owner = "John Ajera"
  }
}

resource "aws_ecs_service" "cwagent" {
  name                = "cwagent-example"
  cluster             = aws_ecs_cluster.example.id
  launch_type         = "EC2"
  propagate_tags      = "TASK_DEFINITION"
  scheduling_strategy = "DAEMON"
  task_definition     = aws_ecs_task_definition.cwagent.arn

  enable_ecs_managed_tags = true

  deployment_controller {
    type = "ECS"
  }

  tags = {
    Name  = "tf-ecs-service-cwagent-example"
    Owner = "John Ajera"
  }
}

resource "aws_cloudwatch_log_group" "webapp" {
  name              = "webapp"
  retention_in_days = 1

  tags = {
    Name  = "tf-cw-log-group-webapp"
    Owner = "John Ajera"
  }
}

resource "aws_ecs_task_definition" "webapp" {
  family                   = "webapp-example"
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
        "awslogs-group"         = "webapp",
        "awslogs-region"        = "ap-southeast-1",
        "awslogs-stream-prefix" = "replica",
      }
    },
  }])

  volume {
    name = "html-volume"
  }

  tags = {
    Name  = "tf-ecs-task-definition-webapp-example"
    Owner = "John Ajera"
  }
}

resource "aws_ecs_service" "webapp" {
  name                = "webapp-example"
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
    target_group_arn = aws_lb_listener.example.default_action[0].target_group_arn
    container_name   = "nginx"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [
      desired_count,
    ]
  }

  tags = {
    Name  = "tf-ecs-service-webapp-example"
    Owner = "John Ajera"
  }
}

resource "aws_appautoscaling_target" "webapp" {
  max_capacity       = 6
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.example.name}/${aws_ecs_service.webapp.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Name  = "tf-ecs-appautoscaling-target-webapp-example"
    Owner = "John Ajera"
  }
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
