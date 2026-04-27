#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"
source "${ROOT_DIR}/.devtool/scripts/action_list.sh"

test_action_list_prints_new_and_modified_packages(){
    DEVTOOL_DIR="/repo"
    NEW_PKG_LIST="/repo/workspace/FEEDS/feed_devtool/new_pkg"
    MOD_PKG_LIST="/repo/workspace/PACKAGES/feeds/base/modified_pkg"

    local output
    output=$(FUNC_action_list)

    assert_contains "${output}" "PKG-NAME" &&
    assert_contains "${output}" "new_pkg" &&
    assert_contains "${output}" "new" &&
    assert_contains "${output}" "workspace/FEEDS/feed_devtool/new_pkg" &&
    assert_contains "${output}" "modified_pkg" &&
    assert_contains "${output}" "modify" &&
    assert_contains "${output}" "workspace/PACKAGES/feeds/base/modified_pkg"
}

test_action_list_uses_compact_row_spacing(){
    DEVTOOL_DIR="/repo"
    NEW_PKG_LIST="/repo/workspace/FEEDS/feed_devtool/new_pkg"
    MOD_PKG_LIST="/repo/workspace/PACKAGES/feeds/base/modified_pkg"

    local output
    output=$(FUNC_action_list)

    [[ "${output}" == $'\n|No.'* ]] &&
    [[ "${output}" == *$'PKG-PATH'*$'\n\n|1  '* ]] &&
    [[ "${output}" == *$'workspace/FEEDS/feed_devtool/new_pkg'*$'\n|2  '* ]] &&
    [[ "${output}" != *$'workspace/FEEDS/feed_devtool/new_pkg'*$'\n\n|2  '* ]]
}

test_case "FUNC_action_list prints new and modified packages" test_action_list_prints_new_and_modified_packages
test_case "FUNC_action_list uses compact row spacing" test_action_list_uses_compact_row_spacing
finish_tests
