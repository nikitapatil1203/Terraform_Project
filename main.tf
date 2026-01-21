resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_subnet" "subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = "us-east-1a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  availability_zone       = "us-east-1b"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
}


resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}


resource "aws_route_table_association" "RT_Subnet1" {
  subnet_id      = aws_subnet.subnet_1.id
  route_table_id = aws_route_table.RT.id
}


resource "aws_route_table_association" "RT_Subnet2" {
  subnet_id      = aws_subnet.subnet_2.id
  route_table_id = aws_route_table.RT.id
}



resource "aws_security_group" "SG" {
  name   = "web-server-sg"
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    description = "SSH ingress"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}



resource "aws_instance" "ec2_instance_1" {
  ami             = "ami-0ecb62995f68bb549"
  instance_type   = "t3.micro"
  subnet_id       = aws_subnet.subnet_1.id
  security_groups = [aws_security_group.SG.id]
  user_data       = file("user_data.sh")
}

resource "aws_instance" "ec2_instance_2" {
  ami             = "ami-0ecb62995f68bb549"
  instance_type   = "t3.micro"
  subnet_id       = aws_subnet.subnet_2.id
  security_groups = [aws_security_group.SG.id]
  user_data       = file("user_data1.sh")
}

resource "aws_lb_target_group" "targetGroup" {
  name             = "myTargetGroup"
  port             = 80
  protocol         = "HTTP"
  vpc_id           = aws_vpc.my_vpc.id
  ip_address_type  = "ipv4"
  protocol_version = "HTTP1"
  health_check {
    protocol = "HTTP"
    path     = "/"
  }
}


resource "aws_lb" "load_balancer" {
  name               = "load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.SG.id]
  subnets            = [aws_subnet.subnet_1.id, aws_subnet.subnet_2.id]
  ip_address_type    = "ipv4"
}



resource "aws_lb_target_group_attachment" "attachTargetGroup1" {
  target_group_arn = aws_lb_target_group.targetGroup.arn
  target_id        = aws_instance.ec2_instance_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attachTargetGroup2" {
  target_group_arn = aws_lb_target_group.targetGroup.arn
  target_id        = aws_instance.ec2_instance_2.id
  port             = 80
}



resource "aws_lb_listener" "my_listener" {
  load_balancer_arn = aws_lb.load_balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.targetGroup.arn
  }
}






