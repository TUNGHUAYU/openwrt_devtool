#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"

test_devtool_print_respects_log_level(){
    LOG_LEVEL=${LOG_WARN}
    VERBOSE=0

    local output
    output=$(devtool_print "${LOG_INFO}" "hidden message")
    assert_eq "" "${output}"

    output=$(devtool_print "${LOG_ERRO}" "visible message")
    assert_eq "visible message" "${output}"
}

test_devtool_print_verbose_prefixes_level(){
    LOG_LEVEL=${LOG_INFO}
    VERBOSE=1

    local output
    output=$(devtool_print "${LOG_INFO}" "verbose message")

    assert_eq "INFO: verbose message" "${output}"
}

test_write_env_value_updates_file_impl(){
    local tmpdir=$1
    local conf_file="${tmpdir}/sample.conf"
    VERBOSE=0
    printf "OPENWRT_DIR=/old/path\nOTHER=value\n" > "${conf_file}"

    FUNC_write_env_value "OPENWRT_DIR" "/new/path" "${conf_file}"

    local content
    content=$(cat "${conf_file}")
    assert_contains "${content}" "OPENWRT_DIR=/new/path" &&
    assert_contains "${content}" "OTHER=value" &&
    assert_eq "/new/path" "${OPENWRT_DIR}"
}

test_write_env_value_updates_file(){
    with_temp_repo test_write_env_value_updates_file_impl
}

test_write_env_value_missing_file_sets_error(){
    RESULT="unset"

    FUNC_write_env_value "OPENWRT_DIR" "/new/path" "/tmp/openwrt-devtool-missing-$$.conf" >/dev/null
    local status=$?

    assert_status "${ERROR_FILE_NO_EXIST}" "${status}" &&
    assert_eq "${RESULT_ERROR}" "${RESULT}"
}

test_check_git_conf_reads_temp_home_impl(){
    local tmpdir=$1
    local old_home=${HOME}
    HOME="${tmpdir}"
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"
    RESULT="unset"

    FUNC_check_git_conf >/dev/null
    local status=$?
    HOME="${old_home}"

    assert_status 0 "${status}" &&
    assert_eq "${RESULT_OK}" "${RESULT}"
}

test_check_git_conf_reads_temp_home(){
    with_temp_repo test_check_git_conf_reads_temp_home_impl
}

test_check_git_conf_missing_identity_sets_error_impl(){
    local tmpdir=$1
    local old_home=${HOME}
    HOME="${tmpdir}"
    RESULT="unset"

    FUNC_check_git_conf >/dev/null
    local status=$?
    HOME="${old_home}"

    assert_status 0 "${status}" &&
    assert_eq "${RESULT_NOK}" "${RESULT}"
}

test_check_git_conf_missing_identity_sets_error(){
    with_temp_repo test_check_git_conf_missing_identity_sets_error_impl
}

test_case "devtool_print respects log level" test_devtool_print_respects_log_level
test_case "devtool_print prefixes verbose messages" test_devtool_print_verbose_prefixes_level
test_case "FUNC_write_env_value updates config files" test_write_env_value_updates_file
test_case "FUNC_write_env_value reports missing files" test_write_env_value_missing_file_sets_error
test_case "FUNC_check_git_conf accepts configured identity" test_check_git_conf_reads_temp_home
test_case "FUNC_check_git_conf rejects missing identity" test_check_git_conf_missing_identity_sets_error
finish_tests
