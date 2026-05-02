################################
# Launch Template
################################
resource "aws_launch_template" "pritunl" {
  name_prefix   = "pritunl-"
  image_id      = var.ami_id
  instance_type = "t3.small"
  key_name      = var.key_name

  # Subnet public -> IP publique automatique
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2.id]
  }

  # Injection automatique de l'URI MongoDB dédiée
  user_data = base64encode(templatefile("${path.module}/userdata/pritunl_install.sh", {
    mongodb_uri = "mongodb://${aws_instance.mongodb.private_ip}:27017/pritunl"
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name    = "pritunl-node"
      Project = "pritunl-ha"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [aws_instance.mongodb]
}

################################
# Auto Scaling Group - subnets PUBLICS
################################
resource "aws_autoscaling_group" "pritunl" {
  name                = "pritunl-asg"
  min_size            = 1
  max_size            = 3
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  target_group_arns   = [aws_lb_target_group.pritunl.arn]

  launch_template {
    id      = aws_launch_template.pritunl.id
    version = "$Latest"
  }

  health_check_type         = "ELB"
  health_check_grace_period = 300

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = "pritunl-node"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

################################
# Auto Scaling Policies
################################
resource "aws_autoscaling_policy" "scale_out" {
  name                   = "pritunl-scale-out"
  autoscaling_group_name = aws_autoscaling_group.pritunl.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "pritunl-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.pritunl.name
  }
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "pritunl-scale-in"
  autoscaling_group_name = aws_autoscaling_group.pritunl.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "pritunl-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.pritunl.name
  }
}
