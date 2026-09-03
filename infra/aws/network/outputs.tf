output "vpc_id" {
  value       = aws_vpc.this.id
  description = "VPC ID for the workload root."
}

output "public_subnet_ids" {
  value = [
    for k in sort(keys(aws_subnet.public)) : aws_subnet.public[k].id
  ]
  description = "Public subnet IDs for the workload root."
}

