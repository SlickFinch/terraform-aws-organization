# Lets accounts share resources such as a Transit Gateway with the Organization without invitations; it also turns on RAM trusted access.
resource "aws_ram_sharing_with_organization" "this" {
  count = var.enable_ram_sharing_with_organization ? 1 : 0

  depends_on = [aws_organizations_organization.this]
}
