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

test_devtool_print_supports_format_arguments(){
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    local output
    output=$(devtool_print "${LOG_CORE}" "|%-5s|%-10s|" "No." "PKG")

    assert_eq "|No.  |PKG       |" "${output}"
}

test_devtool_print_keeps_plain_percent_literal(){
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    local output
    output=$(devtool_print "${LOG_CORE}" "progress 100%")

    assert_eq "progress 100%" "${output}"
}

test_devtool_print_verbose_prefixes_formatted_message(){
    LOG_LEVEL=${LOG_INFO}
    VERBOSE=1

    local output
    output=$(devtool_print "${LOG_INFO}" "%s=%s" "PKG" "demo")

    assert_eq "INFO: PKG=demo" "${output}"
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

test_tui_select_named_title_override_impl(){
    local tmpdir=$1
    local output=""
    local output_file="${tmpdir}/output.txt"
    local status=0
    local item="${tmpdir}/Makefile.cmake.generic"
    touch "${item}"
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    FUNC_tui_select \
        "${item}" \
        --search-path "${tmpdir}/" \
        --message "Please select Makefile style:" \
        --title "MAKEFILE STYLE|MAKEFILE PATH" >"${output_file}" 2>&1 <<< "1"
    status=$?
    output=$(cat "${output_file}")

    assert_status 0 "${status}" &&
    assert_contains "${output}" "MAKEFILE STYLE" &&
    assert_contains "${output}" "MAKEFILE PATH" &&
    [[ "${output}" != *"PKG-NAME"* ]] &&
    assert_eq "${item}" "${RESULT}"
}

test_tui_select_named_title_override(){
    with_temp_repo test_tui_select_named_title_override_impl
}

test_tui_select_default_title_for_path_items_impl(){
    local tmpdir=$1
    local output=""
    local output_file="${tmpdir}/output.txt"
    local item="${tmpdir}/pkg"
    mkdir -p "${item}"
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    FUNC_tui_select \
        "${item}" \
        --search-path "${tmpdir}/" \
        --message "Select package:" >"${output_file}" 2>&1 <<< "1"
    output=$(cat "${output_file}")

    assert_contains "${output}" "PKG-NAME" &&
    assert_contains "${output}" "PKG-PATH" &&
    assert_eq "${item}" "${RESULT}"
}

test_tui_select_default_title_for_path_items(){
    with_temp_repo test_tui_select_default_title_for_path_items_impl
}

test_tui_select_plain_items(){
    local output=""
    local output_file=""
    output_file=$(mktemp)
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    FUNC_tui_select \
        "alpha beta" \
        --item-mode plain \
        --message "Select item:" \
        --title "FEATURE" >"${output_file}" 2>&1 <<< "2"
    output=$(cat "${output_file}")

    assert_contains "${output}" "FEATURE" &&
    assert_contains "${output}" "alpha" &&
    assert_contains "${output}" "beta" &&
    assert_contains "${output}" "Select: beta" &&
    assert_eq "beta" "${RESULT}"
    local status=$?
    rm -f "${output_file}"
    return "${status}"
}

test_tui_select_plain_items_use_compact_row_spacing(){
    local output=""
    local output_file=""
    output_file=$(mktemp)
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    FUNC_tui_select \
        "alpha beta" \
        --item-mode plain \
        --message "Select item:" \
        --title "FEATURE" >"${output_file}" 2>&1 <<< "2"
    output=$(cat "${output_file}")

    [[ "${output}" == $'\n---\n|No.'* ]] &&
    [[ "${output}" == *$'FEATURE                                           \n\n|1   '* ]] &&
    [[ "${output}" == *$'alpha                                             \n|2   '* ]] &&
    [[ "${output}" != *$'alpha                                             \n\n|2   '* ]]
    local status=$?
    rm -f "${output_file}"
    return "${status}"
}

test_tui_select_empty_list_returns_error(){
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0
    RESULT="keep"

    FUNC_tui_select "" --message "Select item:" >/dev/null
    local status=$?

    assert_status "${ERROR_NO_MATCHING_PKG}" "${status}" &&
    assert_eq "" "${RESULT}"
}

test_tui_select_invalid_selection_returns_error_impl(){
    local tmpdir=$1
    local item="${tmpdir}/pkg"
    mkdir -p "${item}"
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0
    RESULT="keep"

    FUNC_tui_select \
        "${item}" \
        --search-path "${tmpdir}/" \
        --message "Select package:" >/dev/null <<< "2"
    local status=$?

    assert_status "${ERROR_ILLEGAL_COMMAND}" "${status}" &&
    assert_eq "" "${RESULT}"
}

test_tui_select_invalid_selection_returns_error(){
    with_temp_repo test_tui_select_invalid_selection_returns_error_impl
}

test_tui_select_legacy_positional_arguments_impl(){
    local tmpdir=$1
    local output=""
    local output_file="${tmpdir}/output.txt"
    local item="${tmpdir}/legacy"
    mkdir -p "${item}"
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    FUNC_tui_select \
        "${item}" \
        "${tmpdir}/" \
        "Select legacy:" \
        "%-20s|%-40s \n" \
        "LEGACY NAME|LEGACY PATH" >"${output_file}" 2>&1 <<< "1"
    output=$(cat "${output_file}")

    assert_contains "${output}" "LEGACY NAME" &&
    assert_contains "${output}" "LEGACY PATH" &&
    assert_contains "${output}" "Select legacy:" &&
    assert_eq "${item}" "${RESULT}"
}

test_tui_select_legacy_positional_arguments(){
    with_temp_repo test_tui_select_legacy_positional_arguments_impl
}

test_tui_select_missing_option_value_returns_error(){
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0
    RESULT="keep"

    FUNC_tui_select "alpha" --title >/dev/null
    local status=$?

    assert_status "${ERROR_ILLEGAL_COMMAND}" "${status}" &&
    assert_eq "" "${RESULT}"
}

test_new_action_declares_specific_menu_titles(){
    local content
    content=$(cat "${ROOT_DIR}/.devtool/scripts/action_new.sh")

    assert_contains "${content}" "MAKEFILE STYLE|MAKEFILE PATH" &&
    assert_contains "${content}" "SOURCE|SOURCE PATH"
}

test_case "devtool_print respects log level" test_devtool_print_respects_log_level
test_case "devtool_print prefixes verbose messages" test_devtool_print_verbose_prefixes_level
test_case "devtool_print supports format arguments" test_devtool_print_supports_format_arguments
test_case "devtool_print keeps plain percent literal" test_devtool_print_keeps_plain_percent_literal
test_case "devtool_print prefixes formatted verbose messages" test_devtool_print_verbose_prefixes_formatted_message
test_case "FUNC_write_env_value updates config files" test_write_env_value_updates_file
test_case "FUNC_write_env_value reports missing files" test_write_env_value_missing_file_sets_error
test_case "FUNC_check_git_conf accepts configured identity" test_check_git_conf_reads_temp_home
test_case "FUNC_check_git_conf rejects missing identity" test_check_git_conf_missing_identity_sets_error
test_case "FUNC_tui_select supports named title override" test_tui_select_named_title_override
test_case "FUNC_tui_select keeps default path title" test_tui_select_default_title_for_path_items
test_case "FUNC_tui_select supports plain menu items" test_tui_select_plain_items
test_case "FUNC_tui_select uses compact row spacing" test_tui_select_plain_items_use_compact_row_spacing
test_case "FUNC_tui_select reports empty lists" test_tui_select_empty_list_returns_error
test_case "FUNC_tui_select reports invalid selections" test_tui_select_invalid_selection_returns_error
test_case "FUNC_tui_select preserves legacy positional arguments" test_tui_select_legacy_positional_arguments
test_case "FUNC_tui_select reports missing option values" test_tui_select_missing_option_value_returns_error
test_case "new action declares specific menu titles" test_new_action_declares_specific_menu_titles
finish_tests
