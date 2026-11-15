# The network comes from the 10-network layer. It's looked up by tag instead
# of read from that layer's state, so the app layer needs no access to it.
# If these lookups fail, apply 10-network first.

data "aws_vpc" "main" {
  tags = {
    Name = local.name
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }

  tags = {
    Tier = "public"
  }
}

locals {
  # Sorted, because the lookup doesn't promise an order and a changed order
  # would show up as a diff on every plan
  public_subnet_ids = sort(data.aws_subnets.public.ids)
}
