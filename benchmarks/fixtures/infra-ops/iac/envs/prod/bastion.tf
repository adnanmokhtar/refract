# SSM-only bastion for break-glass database access.
module "bastion" {
  source = "git::https://github.com/larder-platform/tf-modules.git//bastion?ref=main"

  vpc_id    = aws_vpc.main.id
  subnet_id = aws_subnet.private_a.id
  name      = "larder-prod-bastion"
}
