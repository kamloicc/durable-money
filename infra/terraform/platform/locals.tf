locals {
  short_name = "dm"

  common_tags = merge(var.tags, {
    repository = "kamloicc/durable-money"
  })
}
