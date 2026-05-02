################################
# Application Load Balancer
################################
resource "aws_lb" "main" {
  name               = "pritunl-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = false  # mettre true en production

  tags = { Name = "pritunl-alb" }
}

################################
# Target Group
################################
resource "aws_lb_target_group" "pritunl" {
  name     = "pritunl-tg-3"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTPS"
    port                = "443"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 10
    matcher             = "200-404"  # 404 est retourné par Pritunl sur /
  }

  tags = { Name = "pritunl-tg" }
}
################################
# Listener HTTPS (avec cert ACM)
################################
resource "aws_lb_listener" "https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pritunl.arn
  }
}

################################
# Listener HTTP -> HTTPS redirect
################################
resource "aws_lb_listener" "http_redirect" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

################################
# Listener HTTP direct (sans cert)
# Utilisé pour tester sans domaine
################################
resource "aws_lb_listener" "http_direct" {
  count             = var.acm_certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pritunl.arn
  }
}
