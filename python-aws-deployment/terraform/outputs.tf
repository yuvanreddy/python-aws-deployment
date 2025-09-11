# outputs.tf - Output definitions for Terraform configuration

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.main.id
}

output "instance_ids" {
  description = "IDs of the EC2 instances"
  value       = aws_instance.python_servers[*].id
}

output "public_ips" {
  description = "Public IP addresses of the EC2 instances"
  value       = aws_instance.python_servers[*].public_ip
}

output "private_ips" {
  description = "Private IP addresses of the EC2 instances"
  value       = aws_instance.python_servers[*].private_ip
}

output "instance_details" {
  description = "Detailed information about EC2 instances"
  value = [
    for instance in aws_instance.python_servers : {
      id         = instance.id
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      state      = instance.instance_state
      type       = instance.instance_type
      az         = instance.availability_zone
    }
  ]
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to instances"
  value = [
    for instance in aws_instance.python_servers : 
    "ssh -i ~/.ssh/${var.key_pair_name}.pem ${var.os_type == "ubuntu" ? "ubuntu" : "ec2-user"}@${instance.public_ip}"
  ]
}