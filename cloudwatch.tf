resource "aws_cloudwatch_log_group" "private" {
  name              = "/ecs-${random_string.suffix.result}/ecs/cluster/private"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "cwagent" {
  name              = "/ecs-${random_string.suffix.result}/ecs/service/cwagent"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "exec" {
  name              = "/ecs-${random_string.suffix.result}/ecs/service/exec"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_cloudwatch_log_group" "webapp" {
  name              = "/ecs-${random_string.suffix.result}/ecs/service/webapp"
  retention_in_days = 1

  lifecycle {
    prevent_destroy = false
  }
}
