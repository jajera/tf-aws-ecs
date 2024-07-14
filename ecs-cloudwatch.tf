resource "aws_ecs_task_definition" "cwagent" {
  cpu                      = 128
  memory                   = 256
  family                   = "cwagent-${random_string.suffix.result}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.cwagent_assume.arn
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
        valueFrom = "cwagent-${random_string.suffix.result}-config",
      },
    ],

    logConfiguration = {
      logDriver = "awslogs",
      options = {
        "awslogs-create-group"  = "True",
        "awslogs-group"         = "/ecs-${random_string.suffix.result}/ecs/service/cwagent",
        "awslogs-region"        = "${data.aws_region.current.name}",
        "awslogs-stream-prefix" = "daemon",
      }
    },
  }])
}

resource "aws_ecs_service" "cwagent" {
  name                = "cwagent"
  cluster             = aws_ecs_cluster.example.id
  launch_type         = "EC2"
  propagate_tags      = "TASK_DEFINITION"
  scheduling_strategy = "DAEMON"
  task_definition     = aws_ecs_task_definition.cwagent.arn

  enable_ecs_managed_tags = true

  deployment_controller {
    type = "ECS"
  }

  depends_on = [
    aws_cloudwatch_log_group.cwagent
  ]
}
