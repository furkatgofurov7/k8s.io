/*
Copyright 2023 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

locals {
  permissions_map = merge(
    {
      "sig-k8s-infra-leads" = [
        "AdministratorAccess",
      ]
      "aws-readonly" = [
        "ReadOnlyAccess",
      ]
    },
    var.permissions_map
  )
  group_assignments = merge([
    for group_name, permission_sets in local.permissions_map : {
      for permission_set_name in permission_sets : "${group_name}.${permission_set_name}" => {
        group_name          = group_name
        permission_set_name = permission_set_name
      }
    }
  ]...)
  groups = toset(flatten([
    for group, v in local.permissions_map : group
  ]))
  permission_sets = toset(flatten([
    for group, v in local.permissions_map : [
      for group_name in v : group_name
    ]
  ]))
}

data "aws_identitystore_group" "groups" {
  for_each = local.groups

  identity_store_id = var.identity_store_id
  alternate_identifier {
    unique_attribute {
      attribute_path  = "DisplayName"
      attribute_value = each.value
    }
  }
}

data "aws_ssoadmin_permission_set" "permission_sets" {
  for_each     = local.permission_sets
  instance_arn = var.sso_instance_arn
  name         = each.value
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each           = local.group_assignments
  instance_arn       = var.sso_instance_arn
  permission_set_arn = data.aws_ssoadmin_permission_set.permission_sets[each.value.permission_set_name].arn

  principal_id   = data.aws_identitystore_group.groups[each.value.group_name].id
  principal_type = "GROUP"

  target_id   = aws_organizations_account.this.id
  target_type = "AWS_ACCOUNT"
}
