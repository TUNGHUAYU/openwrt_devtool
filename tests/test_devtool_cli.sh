#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"

test_bash_devtool_sh_resolves_repo_dir(){
    local output
    output=$(cd "${ROOT_DIR}" && bash -x devtool.sh patch demo_plugin test 2>&1)

    assert_contains "${output}" "+ DEVTOOL_DIR=${ROOT_DIR}" &&
    assert_contains "${output}" "+ source ${ROOT_DIR}/.devtool/scripts/action_patch.sh"
}

test_help_prints_pretty_sections(){
    local output
    output=$(cd "${ROOT_DIR}" && bash devtool.sh help 2>&1)

    assert_contains "${output}" "OpenWrt Devtool" &&
    assert_contains "${output}" "Usage: ./devtool.sh <command> [options]" &&
    assert_contains "${output}" "Commands:" &&
    assert_contains "${output}" "new" &&
    assert_contains "${output}" "modify" &&
    assert_contains "${output}" "patch" &&
    assert_contains "${output}" "abort" &&
    assert_contains "${output}" "list" &&
    assert_contains "${output}" "help" &&
    assert_contains "${output}" "Examples:" &&
    assert_contains "${output}" "./devtool.sh modify libcap-ng --dry-run" &&
    assert_contains "${output}" "Builds run through the configured OpenWrt tree."
}

test_illegal_command_prints_pretty_help(){
    local output
    output=$(cd "${ROOT_DIR}" && bash devtool.sh does-not-exist 2>&1 || true)

    assert_contains "${output}" "ILLEGAL COMMAND: does-not-exist" &&
    assert_contains "${output}" "OpenWrt Devtool" &&
    assert_contains "${output}" "Usage: ./devtool.sh <command> [options]"
}

test_case "bash devtool.sh resolves DEVTOOL_DIR to repo root" test_bash_devtool_sh_resolves_repo_dir
test_case "bash devtool.sh help prints pretty sections" test_help_prints_pretty_sections
test_case "illegal command prints pretty help" test_illegal_command_prints_pretty_help
finish_tests
