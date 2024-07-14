resource "aws_ecs_task_definition" "exec" {
  cpu                      = 256
  memory                   = 512
  family                   = "exec-${random_string.suffix.result}"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  task_role_arn            = aws_iam_role.exec_assume.arn
  execution_role_arn       = aws_iam_role.exec_execution.arn

  container_definitions = jsonencode([{
    name                   = "exec"
    image                  = "amazonlinux:2023"
    cpu                    = 256
    memory                 = 512
    essential              = true
    interactive            = true
    pseudoTerminal         = true
    enable_execute_command = true

    linuxParameters = {
      initProcessEnabled = true
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-create-group"  = "True",
        "awslogs-group"         = "/ecs-${random_string.suffix.result}/ecs/service/exec",
        "awslogs-region"        = "${data.aws_region.current.name}",
        "awslogs-stream-prefix" = "replica"
      }
    }
    interactive    = true
    pseudoTerminal = true
    }
  ])
}

resource "aws_ecs_service" "exec" {
  name                = "exec"
  cluster             = aws_ecs_cluster.example.id
  launch_type         = "EC2"
  propagate_tags      = "TASK_DEFINITION"
  scheduling_strategy = "REPLICA"
  task_definition     = aws_ecs_task_definition.exec.arn

  enable_ecs_managed_tags = true
  desired_count           = 1

  deployment_controller {
    type = "ECS"
  }

  depends_on = [
    aws_cloudwatch_log_group.exec
  ]
}
