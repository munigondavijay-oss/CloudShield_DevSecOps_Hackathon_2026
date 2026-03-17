# Create VPC
resource "aws_vpc" "devsecops_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "devsecops-vpc"
  }
}

# Subnet 1 (us-east-1a)
resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.devsecops_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "devsecops-subnet-1"
  }
}

# Subnet 2 (us-east-1b)
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.devsecops_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "devsecops-subnet-2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.devsecops_vpc.id

  tags = {
    Name = "devsecops-igw"
  }
}

# Route Table
resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.devsecops_vpc.id

  tags = {
    Name = "devsecops-route-table"
  }
}

# Internet Route
resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Associate Route Table with Subnet 1
resource "aws_route_table_association" "subnet1_association" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.route_table.id
}

# Associate Route Table with Subnet 2
resource "aws_route_table_association" "subnet2_association" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.route_table.id
}

########################################################
# ECR
########################################################

resource "aws_ecr_repository" "repo" {
  name = "hackathon-repo"
}

########################################################
# IAM ROLE FOR EC2
########################################################

resource "aws_iam_role" "ec2_role" {

  name = "ec2-devops-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr" {

  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {

  name = "ec2-devsecops-profile"
  role = aws_iam_role.ec2_role.name
}

########################################################
# EKS ROLE
########################################################

resource "aws_iam_role" "eks_role" {

  name = "eks-vijay-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"

      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_policy" {

  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

########################################################
# EKS CLUSTER
########################################################

resource "aws_eks_cluster" "eks" {

  name     = "hackathon-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {

    subnet_ids = [
      aws_subnet.subnet1.id,
      aws_subnet.subnet2.id
    ]

    endpoint_public_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_policy
  ]
}

########################################################
# NODE ROLE
########################################################

resource "aws_iam_role" "node_role" {

  name = "eks-vijay-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_policy1" {

  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_policy2" {

  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_policy3" {

  role       = aws_iam_role.node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

########################################################
# NODE GROUP
########################################################

resource "aws_eks_node_group" "nodes" {

  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "hackathon-nodes"

  node_role_arn = aws_iam_role.node_role.arn

  subnet_ids = [
    aws_subnet.subnet1.id,
    aws_subnet.subnet2.id
  ]

  scaling_config {

    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.medium"]

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role_policy_attachment.node_policy1,
    aws_iam_role_policy_attachment.node_policy2,
    aws_iam_role_policy_attachment.node_policy3
  ]
}