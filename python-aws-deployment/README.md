# Python AWS Deployment with GitHub Actions

This repository provides a complete Infrastructure as Code (IaC) solution for deploying Python environments on AWS EC2 instances using Terraform and Ansible, orchestrated through GitHub Actions.

## 🚀 Features

- **Automated Infrastructure Provisioning**: Creates VPC, subnets, security groups, and EC2 instances
- **Python Environment Setup**: Installs and configures Python with specified packages
- **Three-Stage Workflow**: Separate workflows for create, configure, and destroy
- **Multi-OS Support**: Ubuntu, Amazon Linux 2, and RHEL
- **SSM Integration**: Uses AWS Systems Manager for secure instance access
- **State Management**: Terraform state stored in S3 with DynamoDB locking
- **Safety Checks**: Confirmation required for destructive operations
- **Backup Support**: Optional backup before infrastructure destruction

## 📋 Prerequisites

### AWS Requirements
1. AWS Account with appropriate permissions
2. EC2 Key Pair created in your target region
3. IAM user with programmatic access

### GitHub Repository Setup
Add the following secrets to your GitHub repository:
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key  
- `AWS_REGION` - Target AWS region (e.g., `us-east-1`)
- `KEY_PAIR_NAME` - Name of your EC2 key pair

## 🏗️ Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── 01-create-infrastructure.yml    # Creates AWS resources
│       ├── 02-install-python.yml          # Installs Python
│       └── 03-destroy-infrastructure.yml   # Destroys resources
├── terraform/
│   ├── main.tf                            # Main Terraform configuration
│   ├── variables.tf                       # Variable definitions
│   ├── outputs.tf                         # Output definitions
│   └── versions.tf                        # Provider versions
├── ansible/
│   └── (dynamically created)              # Ansible playbooks
└── README.md
```

## 🎯 Usage

### Step 1: Create Infrastructure

1. Go to **Actions** tab in your GitHub repository
2. Select **"01 - Create AWS Infrastructure"**
3. Click **"Run workflow"**
4. Configure parameters:
   - **Instance Count**: Number of EC2 instances (1-5)
   - **Instance Type**: EC2 instance type (t3.micro, t3.small, etc.)
   - **OS Type**: Operating system (ubuntu, amazon-linux-2, rhel)
5. Click **"Run workflow"** button

The workflow will:
- Create a VPC with public subnet
- Set up security groups with SSH, HTTP, HTTPS access
- Launch EC2 instances with SSM agent
- Configure IAM roles for SSM access
- Output instance IDs and IP addresses

### Step 2: Install Python

1. Go to **Actions** tab
2. Select **"02 - Install Python"**
3. Click **"Run workflow"**
4. Configure parameters:
   - **Python Version**: Version to install (3.9, 3.10, 3.11, 3.12)
   - **Pip Packages**: Comma-separated list of packages
   - **Verify Installation**: Run verification tests
5. Click **"Run workflow"** button

The workflow will:
- Connect to instances via SSM
- Install Python and development tools
- Install specified pip packages
- Verify installation
- Display Python version and installed packages

### Step 3: Destroy Infrastructure (When Needed)

1. Go to **Actions** tab
2. Select **"03 - Destroy Infrastructure"**
3. Click **"Run workflow"**
4. Configure parameters:
   - **Confirm Destroy**: Type `DESTROY` to confirm
   - **Backup Before Destroy**: Create backup (true/false)
5. Click **"Run workflow"** button

The workflow will:
- Create backup of current state (if enabled)
- Destroy all EC2 instances
- Remove VPC and associated resources
- Clean up Terraform state
- Upload backup as artifact (if created)

## 🔧 Customization

### Modifying Infrastructure

Edit `terraform/variables.tf` to change defaults:
```hcl
variable "vpc_cidr" {
  default = "10.0.0.0/16"  # Change VPC CIDR
}

variable "instance_type" {
  default = "t3.micro"      # Change default instance type
}
```

### Adding Python Packages

When running the "02 - Install Python" workflow, specify packages in the input:
```
boto3,requests,pandas,numpy,flask,django
```

### Extending Functionality

Add new Terraform resources in `terraform/main.tf`:
```hcl
# Example: Add RDS database
resource "aws_db_instance" "database" {
  # Configuration here
}
```

## 🔍 Monitoring and Troubleshooting

### View Terraform Outputs

After infrastructure creation, check the workflow logs for:
- Instance IDs
- Public/Private IP addresses
- VPC and Subnet IDs
- SSH connection commands

### Access Instances

**Via SSH:**
```bash
ssh -i ~/.ssh/your-key.pem ubuntu@<public-ip>
```

**Via AWS Systems Manager:**
```bash
aws ssm start-session --target <instance-id>
```

### Common Issues

1. **Workflow fails with "key pair not found"**
   - Ensure KEY_PAIR_NAME secret matches an existing key pair in your AWS region

2. **Python installation fails**
   - Check instance has internet connectivity
   - Verify security group allows outbound traffic

3. **Destruction requires confirmation**
   - Must type exactly `DESTROY` to confirm

## 🛡️ Security Considerations

- Terraform state is encrypted in S3
- State locking prevents concurrent modifications
- SSM used for secure instance access
- Security groups restrict inbound traffic
- IAM roles follow least privilege principle

## 💰 Cost Optimization

- Default instance type is t3.micro (free tier eligible)
- Resources are tagged for cost tracking
- Destroy infrastructure when not in use
- Use lifecycle rules on S3 for old state files

## 📊 Resource Tagging

All resources are tagged with:
- `Environment`: dev/staging/prod
- `ManagedBy`: Terraform
- `Project`: PythonDeployment
- `CreatedAt`: Timestamp

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📝 License

This project is open source and available under the MIT License.

## 🆘 Support

For issues or questions:
1. Check the [Actions logs](../../actions) for error details
2. Review AWS CloudWatch logs
3. Open an [issue](../../issues) with:
   - Workflow run link
   - Error messages
   - Configuration used

## 🎉 Quick Start Example

```bash
# 1. Clone the repository
git clone https://github.com/yourusername/python-aws-deployment.git

# 2. Set up GitHub secrets
# Go to Settings → Secrets → Actions → New repository secret

# 3. Run workflows via GitHub CLI (optional)
gh workflow run 01-create-infrastructure.yml
gh workflow run 02-install-python.yml
gh workflow run 03-destroy-infrastructure.yml -f confirm_destroy=DESTROY
```

## 📚 Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Ansible Documentation](https://docs.ansible.com)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2)