data "aws_ssm_parameter" "al2023" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

locals {
  ami_id = var.ami_id != "" ? var.ami_id : nonsensitive(data.aws_ssm_parameter.al2023[0].value)
}

# Plain aws_instance (no launch template): RunInstances with a LaunchTemplate
# answers 501 on the emulator.
resource "aws_instance" "web" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  # Explicit AZ: without it the emulator rejects RunInstances with
  # "Invalid value '' for availabilityZone" (real AWS infers it from the subnet).
  availability_zone           = aws_subnet.public.availability_zone
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data                   = file("${path.module}/user_data.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  tags = { Name = "${var.name}-web" }

  depends_on = [aws_route_table_association.public]
}
