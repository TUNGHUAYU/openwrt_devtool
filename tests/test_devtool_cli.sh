#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"

GREEN=$'\033[0;32m'
NC=$'\033[0m'

assert_help_framed(){
    local file=$1
    local first_hex=""
    local last_two_hex=""

    first_hex=$(od -An -tx1 -N1 "${file}" | tr -d ' \n')
    last_two_hex=$(tail -c 2 "${file}" | od -An -tx1 | tr -d ' \n')

    assert_eq "0a" "${first_hex}" &&
    assert_eq "0a0a" "${last_two_hex}"
}

test_bash_devtool_sh_resolves_repo_dir(){
    local output
    output=$(cd "${ROOT_DIR}" && bash -x devtool.sh patch demo_plugin test 2>&1)

    assert_contains "${output}" "+ DEVTOOL_DIR=${ROOT_DIR}" &&
    assert_contains "${output}" "+ source ${ROOT_DIR}/.devtool/scripts/action_patch.sh"
}

test_help_prints_pretty_sections(){
    local output
    local output_file
    output_file=$(mktemp)
    (cd "${ROOT_DIR}" && bash devtool.sh help >"${output_file}" 2>&1)
    output=$(<"${output_file}")

    assert_help_framed "${output_file}" &&
    assert_contains "${output}" "OpenWrt Devtool" &&
    assert_contains "${output}" "Version: 3.0.0" &&
    assert_contains "${output}" "Usage: ./devtool.sh <command> [options]" &&
    assert_contains "${output}" "${GREEN}Usage: ./devtool.sh <command> [options]${NC}" &&
    assert_contains "${output}" "Commands:" &&
    assert_contains "${output}" "new" &&
    assert_contains "${output}" "modify" &&
    assert_contains "${output}" "patch" &&
    assert_contains "${output}" "finish" &&
    assert_contains "${output}" "abort" &&
    assert_contains "${output}" "list" &&
    assert_contains "${output}" "help" &&
    assert_contains "${output}" "Run ./devtool.sh <command> help for command-specific arguments." &&
    [[ "${output}" != *"new <pkg-name>"* ]] &&
    [[ "${output}" != *"patch [<pkg-pattern>]"* ]] &&
    assert_contains "${output}" "Builds run through the configured OpenWrt tree."
    local status=$?
    rm -f "${output_file}"
    return "${status}"
}

test_new_help_prints_argument_details(){
    local output
    local output_file
    output_file=$(mktemp)
    (cd "${ROOT_DIR}" && bash devtool.sh new help >"${output_file}" 2>&1)
    output=$(<"${output_file}")

    assert_help_framed "${output_file}" &&
    assert_contains "${output}" "Usage: ./devtool.sh new <pkg-name> [<git-url>]" &&
    assert_contains "${output}" "${GREEN}Usage: ./devtool.sh new <pkg-name> [<git-url>]${NC}" &&
    assert_contains "${output}" "<pkg-name>" &&
    assert_contains "${output}" "[<git-url>]" &&
    assert_contains "${output}" "./devtool.sh new demo_plugin" &&
    assert_contains "${output}" "${GREEN}  ./devtool.sh new demo_plugin${NC}" &&
    assert_contains "${output}" "./devtool.sh new demo_plugin https://example.com/demo.git" &&
    assert_contains "${output}" "${GREEN}  ./devtool.sh new demo_plugin https://example.com/demo.git${NC}"
    local status=$?
    rm -f "${output_file}"
    return "${status}"
}

test_modify_help_prints_argument_details(){
    local output
    output=$(cd "${ROOT_DIR}" && bash devtool.sh modify help 2>&1)

    assert_contains "${output}" "Usage: ./devtool.sh modify [<pkg-pattern>] [--dry-run]" &&
    assert_contains "${output}" "[<pkg-pattern>]" &&
    assert_contains "${output}" "[--dry-run]" &&
    assert_contains "${output}" "./devtool.sh modify libcap-ng --dry-run"
}

test_patch_help_prints_argument_details(){
    local output
    local output_file
    output_file=$(mktemp)
    (cd "${ROOT_DIR}" && bash devtool.sh patch help >"${output_file}" 2>&1)
    output=$(<"${output_file}")

    assert_help_framed "${output_file}" &&
    assert_contains "${output}" "Usage: ./devtool.sh patch [<pkg-pattern>] [<base-ref>]" &&
    assert_contains "${output}" "${GREEN}Usage: ./devtool.sh patch [<pkg-pattern>] [<base-ref>]${NC}" &&
    assert_contains "${output}" "[<pkg-pattern>]" &&
    assert_contains "${output}" "[<base-ref>]" &&
    assert_contains "${output}" "Without a package pattern, choose from modified packages." &&
    assert_contains "${output}" "./devtool.sh patch libcap-ng ref-base" &&
    assert_contains "${output}" "${GREEN}  ./devtool.sh patch${NC}" &&
    assert_contains "${output}" "${GREEN}  ./devtool.sh patch libcap-ng ref-base${NC}"
    local status=$?
    rm -f "${output_file}"
    return "${status}"
}

test_finish_help_prints_argument_details(){
    local output
    local output_file
    output_file=$(mktemp)
    (cd "${ROOT_DIR}" && bash devtool.sh finish help >"${output_file}" 2>&1)
    output=$(<"${output_file}")

    assert_help_framed "${output_file}" &&
    assert_contains "${output}" "Usage: ./devtool.sh finish [<pkg-pattern>] [--dry-run]" &&
    assert_contains "${output}" "${GREEN}Usage: ./devtool.sh finish [<pkg-pattern>] [--dry-run]${NC}" &&
    assert_contains "${output}" "[<pkg-pattern>]" &&
    assert_contains "${output}" "[--dry-run]" &&
    assert_contains "${output}" "./devtool.sh finish libcap-ng --dry-run"
    local status=$?
    rm -f "${output_file}"
    return "${status}"
}

test_list_help_prints_command_details(){
    local output
    output=$(cd "${ROOT_DIR}" && bash devtool.sh list help 2>&1)

    assert_contains "${output}" "Usage: ./devtool.sh list" &&
    assert_contains "${output}" "Lists new and modified packages tracked in the devtool workspace."
}

test_abort_help_prints_command_details(){
    local output
    output=$(cd "${ROOT_DIR}" && bash devtool.sh abort help 2>&1)

    assert_contains "${output}" "Usage: ./devtool.sh abort" &&
    assert_contains "${output}" "Removes selected generated package work after confirmation."
}

test_new_without_package_prints_new_help(){
    local output
    local status
    local output_file
    output_file=$(mktemp)
    (cd "${ROOT_DIR}" && bash devtool.sh new >"${output_file}" 2>&1)
    status=$?
    output=$(<"${output_file}")

    assert_status "8" "${status}" &&
    assert_help_framed "${output_file}" &&
    assert_contains "${output}" "Usage: ./devtool.sh new <pkg-name> [<git-url>]" &&
    assert_contains "${output}" "${GREEN}Usage: ./devtool.sh new <pkg-name> [<git-url>]${NC}" &&
    [[ "${output}" != *"Usage: ./devtool.sh <command> [options]"* ]]
    local assert_status_result=$?
    rm -f "${output_file}"
    return "${assert_status_result}"
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
test_case "bash devtool.sh new help prints argument details" test_new_help_prints_argument_details
test_case "bash devtool.sh modify help prints argument details" test_modify_help_prints_argument_details
test_case "bash devtool.sh patch help prints argument details" test_patch_help_prints_argument_details
test_case "bash devtool.sh finish help prints argument details" test_finish_help_prints_argument_details
test_case "bash devtool.sh list help prints command details" test_list_help_prints_command_details
test_case "bash devtool.sh abort help prints command details" test_abort_help_prints_command_details
test_case "bash devtool.sh new without package prints new help" test_new_without_package_prints_new_help
test_case "illegal command prints pretty help" test_illegal_command_prints_pretty_help
finish_tests
