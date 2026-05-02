resource "aws_lb" "nlb" {
  name               = "pritunl-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  tags               = { Name = "pritunl-nlb" }
}

resource "aws_lb_target_group" "nlb_tg" {
  name     = "pritunl-nlb-tg"
  port     = 443
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    protocol = "TCP"
    port     = "443"
  }
}

resource "aws_lb_listener" "nlb_https" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}

resource "aws_autoscaling_attachment" "nlb" {
  autoscaling_group_name = aws_autoscaling_group.pritunl.id
  lb_target_group_arn    = aws_lb_target_group.nlb_tg.arn
}

output "nlb_dns_name" {
  value = aws_lb.nlb.dns_name
}