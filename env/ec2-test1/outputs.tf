output "instance_id" {
  value = aws_instance.web.id
}

output "ami_id" {
  value = local.ami_id
}

output "instance_state" {
  value = aws_instance.web.instance_state
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

output "url" {
  value = "http://${aws_instance.web.public_ip}"
}
