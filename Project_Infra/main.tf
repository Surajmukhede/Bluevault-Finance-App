# Configure the AWS provider and specify the region
provider "aws" {
  region = "ap-south-1" # Mumbai region
}

# configure custom AMI for kubeadm Infra
# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get the first subnet in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "availability-zone"
    values = ["ap-south-1a", "ap-south-1b"]
  }
}

data "aws_subnet" "default" {
  id = data.aws_subnets.default.ids[0]
}

# Create a security group that allows SSH from your public IP
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_kubeadm"
  description = "Allow SSH from my IP"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
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

# EC2 instance for kubeadm setup
resource "aws_instance" "kubeadm" {
  ami                         = "ami-0f918f7e67a3323f0"  # Ubuntu 24.04 LTS
  instance_type               = "t2.medium"
  key_name                    = "ap-south-1"
  subnet_id                   = data.aws_subnet.default.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]

  tags = {
    Name = "kubeadm-setup"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y ansible"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/home/hp/Downloads/ap-south-1.pem")
      host        = self.public_ip
    }
  }
}

# Run your Ansible playbook from local machine after EC2 is up
resource "null_resource" "ansible_provision" {
  depends_on = [aws_instance.kubeadm]

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${aws_instance.kubeadm.public_ip},' /home/hp/Documents/Blue_valut_finance/Infra/kubeadm_setup1.yml --private-key /home/hp/Downloads/ap-south-1.pem -u ubuntu"
  }
}

# Create custom AMI after Ansible has finished
resource "aws_ami_from_instance" "kubeadm_ami" {
  depends_on         = [null_resource.ansible_provision]
  name               = "kubeadm-custom-ami-${formatdate("YYYYMMDD-HHmmss", timestamp())}"
  source_instance_id = aws_instance.kubeadm.id
}



# 1. Create VPC
resource "aws_vpc" "proj_vpc" {
  cidr_block           = "10.77.0.0/17"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "proj-vpc"
  }
}

# 2. Create Internet Gateway and attach to VPC
resource "aws_internet_gateway" "proj_igw" {
  vpc_id = aws_vpc.proj_vpc.id

  tags = {
    Name = "proj-igw"
  }
}

# 3. Create Subnets in different Availability Zones
# Using /24 CIDR blocks for subnets within the /17 VPC
resource "aws_subnet" "sub1_project" {
  vpc_id                  = aws_vpc.proj_vpc.id
  cidr_block              = "10.77.0.0/24"
  availability_zone       = "ap-south-1a" # Example AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "sub1-project"
  }
}

resource "aws_subnet" "sub2_project" {
  vpc_id                  = aws_vpc.proj_vpc.id
  cidr_block              = "10.77.1.0/24"
  availability_zone       = "ap-south-1b" # Example AZ
  map_public_ip_on_launch = true

  tags = {
    Name = "sub2-project"
  }
}

resource "aws_subnet" "sub3_project" {
  vpc_id                  = aws_vpc.proj_vpc.id
  cidr_block              = "10.77.2.0/24"
  availability_zone       = "ap-south-1a" # Corrected: Changed from ap-south-1c to a supported AZ for t2.medium
  map_public_ip_on_launch = true

  tags = {
    Name = "sub3-project"
  }
}

# 4. Create Custom Route Table
resource "aws_route_table" "proj_rt" {
  vpc_id = aws_vpc.proj_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.proj_igw.id
  }

  tags = {
    Name = "proj-rt"
  }
}

# 5. Associate Subnets with the Custom Route Table
resource "aws_route_table_association" "sub1_assoc" {
  subnet_id      = aws_subnet.sub1_project.id
  route_table_id = aws_route_table.proj_rt.id
}

resource "aws_route_table_association" "sub2_assoc" {
  subnet_id      = aws_subnet.sub2_project.id
  route_table_id = aws_route_table.proj_rt.id
}

resource "aws_route_table_association" "sub3_assoc" {
  subnet_id      = aws_subnet.sub3_project.id
  route_table_id = aws_route_table.proj_rt.id
}

# 6. Create Security Groups

# Security Group for Jenkins
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins instance"
  vpc_id      = aws_vpc.proj_vpc.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "jenkins-sg"
  }
}

# Security Group for Kubernetes Control Plane
resource "aws_security_group" "k8s_cp_sg" {
  name        = "k8s-cp-sg"
  description = "Security group for Kubernetes Control Plane"
  vpc_id      = aws_vpc.proj_vpc.id

  # TCP Ingress Rules
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Kubernetes API Server (HTTPS)"
    from_port   = 6443 # Corrected from 2443, common K8s API port
    to_port     = 6443 # Corrected from 2443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "etcd client port"
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "etcd peer port"
    from_port   = 2380
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Kube-scheduler"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Kube-controller-manager"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Calico VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # UDP Ingress Rules
  ingress {
    description = "Calico VXLAN (UDP)"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "DNS (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # IP Protocol 4 (IP-in-IP) for Calico
  ingress {
    description = "IP-in-IP for Calico"
    from_port   = 0 # Applies to all ports for the specified protocol
    to_port     = 0 # Applies to all ports for the specified protocol
    protocol    = "4" # IP-in-IP protocol number
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-cp-sg"
  }
}

# Security Group for Kubernetes Nodes
resource "aws_security_group" "k8s_nodes_sg" {
  name        = "k8s-nodes-sg"
  description = "Security group for Kubernetes Worker Nodes"
  vpc_id      = aws_vpc.proj_vpc.id

  # TCP Ingress Rules
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "NodePort range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Calico VXLAN"
    from_port   = 4789
    to_port     = 4789
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "etcd client port (if nodes also run etcd)"
    from_port   = 2379
    to_port     = 2379
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # UDP Ingress Rules
  ingress {
    description = "Calico VXLAN (UDP)"
    from_port   = 4789
    to_port     = 4789
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "DNS (UDP)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # IP Protocol 4 (IP-in-IP) for Calico
  ingress {
    description = "IP-in-IP for Calico"
    from_port   = 0
    to_port     = 0
    protocol    = "4" # IP-in-IP protocol number
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "k8s-nodes-sg"
  }
}

# 7. Create EC2 Instances

# User data script for the Jenkins instance (RedHat-based AMI)
locals {
  jenkins_user_data = <<-EOF
    #!/bin/bash
    # This script runs on the EC2 instances at launch.

    # 1. Create a new user 'ansible' with a home directory and bash shell.
    # The password for 'ansible' user is set to 'admin@123'.
    # This is for demonstration purposes; in production, use SSH keys for authentication.
    sudo useradd ansible -m -s /bin/bash -p $(openssl passwd -1 admin@123)

    # 2. Grant 'ansible' user passwordless sudo privileges.
    # This allows the 'ansible' user to run commands with root privileges without being prompted for a password.
    echo 'ansible ALL=(ALL:ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo

    # 3. Enable password authentication for SSH.
    # This sed command robustly finds and sets 'PasswordAuthentication yes',
    # handling commented lines or existing 'no' values.
    sudo sed -i -E 's/^[#[:space:]]*PasswordAuthentication[[:space:]]+(yes|no)/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # 4. Enable keyboard interactive authentication for SSH.
    # This sed command robustly finds and sets 'KeyboardInteractiveAuthentication yes',
    # handling commented lines or existing 'no' values.
    # sudo sed -i -E 's/^[#[:space:]]*KbdInteractiveAuthentication[[:space:]]+(yes|no)/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config

    # 5. Restart the SSH daemon to apply the changes.
    # This ensures that the new SSH configuration (including password and keyboard interactive authentication) takes effect immediately.
    sudo systemctl restart sshd
  EOF

  # User data script for Kubernetes Control Plane and Worker Nodes (Ubuntu-based AMIs)
  ubuntu_user_data = <<-EOF
    #!/bin/bash
    # This script runs on the EC2 instances at launch.

    # 1. Create a new user 'ansible' with a home directory and bash shell.
    # The password for 'ansible' user is set to 'admin@123'.
    # This is for demonstration purposes; in production, use SSH keys for authentication.
    sudo useradd ansible -m -s /bin/bash -p $(openssl passwd -1 admin@123)

    # 2. Grant 'ansible' user passwordless sudo privileges.
    # This allows the 'ansible' user to run commands with root privileges without being prompted for a password.
    echo 'ansible ALL=(ALL:ALL) NOPASSWD:ALL' | sudo EDITOR='tee -a' visudo

    # 3. Enable password authentication for SSH.
    # This sed command robustly finds and sets 'PasswordAuthentication yes',
    # handling commented lines or existing 'no' values.
    sudo sed -i -E 's/^[#[:space:]]*PasswordAuthentication[[:space:]]+(yes|no)/PasswordAuthentication yes/' /etc/ssh/sshd_config

    # 4. Enable keyboard interactive authentication for SSH.
    # This sed command robustly finds and sets 'KeyboardInteractiveAuthentication yes',
    # handling commented lines or existing 'no' values.
    sudo sed -i -E 's/^[#[:space:]]*KbdInteractiveAuthentication[[:space:]]+(yes|no)/KbdInteractiveAuthentication yes/' /etc/ssh/sshd_config

    # 5. Restart the SSH daemon to apply the changes.
    # This ensures that the new SSH configuration (including password and keyboard interactive authentication) takes effect immediately.
    sudo systemctl restart ssh
  EOF
}

resource "aws_instance" "jenkins" {
  # IMPORTANT: Replace ami-xxxxxxxxxxxxxxxxx with a valid AMI ID for ap-south-1 (Mumbai)
  # This AMI should be RedHat-based (e.g., Amazon Linux, CentOS, RHEL) for the Jenkins playbook.
  ami           = "ami-0d0ad8bb301edb745"
  instance_type = "t2.medium"
  key_name      = "ap-south-1" # Ensure this key pair exists in your AWS account
  subnet_id     = aws_subnet.sub1_project.id # Place in sub1-project
  vpc_security_group_ids = [
    aws_security_group.jenkins_sg.id
  ]
  root_block_device {
    volume_size = 14 # GiB
  }
  user_data = local.jenkins_user_data # Apply user data only to Jenkins

  tags = {
    Name = "Jenkins"
  }
}

resource "aws_instance" "k8s_cp" {
  # IMPORTANT: Replace ami-xxxxxxxxxxxxxxxxx with a valid AMI ID for ap-south-1 (Mumbai)
  # This AMI should be Ubuntu-based for the Kubernetes playbook.
  ami           = aws_ami_from_instance.kubeadm_ami.id
  instance_type = "t2.medium"
  key_name      = "ap-south-1" # Ensure this key pair exists in your AWS account
  subnet_id     = aws_subnet.sub2_project.id # Place in sub2-project
  vpc_security_group_ids = [
    aws_security_group.k8s_cp_sg.id
  ]
  root_block_device {
    volume_size = 14 # GiB
  }
  user_data = local.ubuntu_user_data # Apply user data for Ubuntu instances

  tags = {
    Name = "CP"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y ansible"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("/home/hp/Downloads/ap-south-1.pem")
      host        = self.public_ip
    }
  }
}

# Run your Ansible playbook from local machine after EC2 is up
resource "null_resource" "ansible_provision_cp" {
  depends_on = [aws_instance.k8s_cp]

  provisioner "local-exec" {
    command = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i '${aws_instance.kubeadm.public_ip},' /home/hp/Documents/Blue_valut_finance/Infra/kubeadm_setup2.yml --private-key /home/hp/Downloads/ap-south-1.pem -u ubuntu"
  }
}

resource "aws_instance" "node1" {
  # IMPORTANT: Replace ami-xxxxxxxxxxxxxxxxx with a valid AMI ID for ap-south-1 (Mumbai)
  # This AMI should be Ubuntu-based for the Kubernetes playbook.
  ami           = aws_ami_from_instance.kubeadm_ami.id
  instance_type = "t2.medium"
  key_name      = "ap-south-1" # Ensure this key pair exists in your AWS account
  subnet_id     = aws_subnet.sub3_project.id # Place in sub3-project
  vpc_security_group_ids = [
    aws_security_group.k8s_nodes_sg.id
  ]
  root_block_device {
    volume_size = 14 # GiB
  }
  user_data = local.ubuntu_user_data # Apply user data for Ubuntu instances

  tags = {
    Name = "Node1"
  }
}

resource "aws_instance" "node2" {
  # IMPORTANT: Replace ami-xxxxxxxxxxxxxxxxx with a valid AMI ID for ap-south-1 (Mumbai)
  # This AMI should be Ubuntu-based for the Kubernetes playbook.
  ami           = aws_ami_from_instance.kubeadm_ami.id
  instance_type = "t2.medium"
  key_name      = "ap-south-1" # Ensure this key pair exists in your AWS account
  subnet_id     = aws_subnet.sub3_project.id # Place in sub3-project
  vpc_security_group_ids = [
    aws_security_group.k8s_nodes_sg.id
  ]
  root_block_device {
    volume_size = 14 # GiB
  }
  user_data = local.ubuntu_user_data # Apply user data for Ubuntu instances

  tags = {
    Name = "Node2"
  }
}
