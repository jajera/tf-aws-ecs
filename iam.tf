resource "aws_iam_role" "ec2_assume" {
  name = "ec2-assume-${random_string.suffix.result}"

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
}

resource "aws_iam_policy" "ec2_assume" {
  name        = "ec2-assume-${random_string.suffix.result}"
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

resource "aws_iam_role_policy_attachment" "ec2_assume" {
  policy_arn = aws_iam_policy.ec2_assume.arn
  role       = aws_iam_role.ec2_assume.name
}

resource "aws_iam_instance_profile" "ec2_assume" {
  name = "ecs-assume-${random_string.suffix.result}"
  role = aws_iam_role.ec2_assume.id
}

data "aws_iam_policy_document" "ecs_assume" {
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

resource "aws_iam_role" "cwagent_assume" {
  name               = "cwagent-task-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json

}

resource "aws_iam_role_policy_attachment" "cwagent_assume" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.cwagent_assume.name
}

resource "aws_iam_role" "cwagent_execution" {
  name               = "cwagent-execution-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
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

resource "aws_iam_role" "exec_assume" {
  name               = "exec-task-${random_string.suffix.result}"
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
    },
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ssm.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "exec_assume" {
  role = aws_iam_role.exec_assume.id
  policy = jsonencode({
    "Statement" : [
      {
        "Action" : [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ],
        "Effect" : "Allow",
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_iam_role" "exec_execution" {
  name               = "exec-execution-${random_string.suffix.result}"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume.json
}

resource "aws_iam_role_policy_attachment" "exec_ecs_task_exec_policy" {
  role       = aws_iam_role.exec_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
