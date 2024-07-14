data "aws_instances" "example" {
  filter {
    name   = "tag:aws:autoscaling:groupName"
    values = [aws_autoscaling_group.example.name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

output "ecs_instance_private_ips" {
  value = data.aws_instances.example.private_ips
}

output "webapp_lb_dns_name" {
  value = aws_lb.webapp.dns_name
}
