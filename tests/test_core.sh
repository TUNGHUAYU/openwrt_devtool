#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"
source "${ROOT_DIR}/.devtool/scripts/_core.sh"

test_empty_openwrt_dir_sets_false(){
    OPENWRT_DIR=""
    RESULT="unset"

    FUNC_exist_openwrt_dir >/dev/null

    assert_eq "${RESULT_FALSE}" "${RESULT}"
}

test_existing_openwrt_dir_sets_true(){
    local tmpdir
    tmpdir=$(mktemp -d)
    OPENWRT_DIR="${tmpdir}"
    RESULT="unset"

    FUNC_is_openwrt_dir >/dev/null
    local status=$?
    rm -rf "${tmpdir}"

    assert_status 0 "${status}" &&
    assert_eq "${RESULT_TRUE}" "${RESULT}"
}

test_missing_openwrt_dir_sets_false(){
    OPENWRT_DIR="/tmp/openwrt-devtool-missing-$$"
    RESULT="unset"

    FUNC_is_openwrt_dir >/dev/null

    assert_eq "${RESULT_FALSE}" "${RESULT}"
}

test_get_new_pkg_list_reads_feed_workspace_impl(){
    local tmpdir=$1
    DEVTOOL_WORKSPACE_FEED_DIR="${tmpdir}/workspace/FEEDS"
    FEED_NAME="feed_devtool"
    mkdir -p "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg"

    FUNC_get_new_pkg_list

    assert_eq "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg" "${NEW_PKG_LIST}"
}

test_get_new_pkg_list_reads_feed_workspace(){
    with_temp_repo test_get_new_pkg_list_reads_feed_workspace_impl
}

test_get_mod_pkg_list_reads_package_makefiles_impl(){
    local tmpdir=$1
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    mkdir -p "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/base/existing_pkg"
    touch "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/base/existing_pkg/Makefile"

    FUNC_get_mod_pkg_list

    assert_eq "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/base/existing_pkg" "${MOD_PKG_LIST}"
}

test_get_mod_pkg_list_reads_package_makefiles(){
    with_temp_repo test_get_mod_pkg_list_reads_package_makefiles_impl
}

test_check_pkg_type_detects_new_package(){
    PKG_NAME="demo_pkg"
    URL=""
    NEW_PKG_LIST="/repo/workspace/FEEDS/feed_devtool/demo_pkg"
    MOD_PKG_LIST=""

    FUNC_check_pkg_type >/dev/null

    assert_eq "new" "${PKG_TYPE}"
}

test_check_pkg_type_detects_modified_package(){
    PKG_NAME="existing_pkg"
    URL=""
    NEW_PKG_LIST=""
    MOD_PKG_LIST="/repo/workspace/PACKAGES/feeds/base/existing_pkg"

    FUNC_check_pkg_type >/dev/null

    assert_eq "modify" "${PKG_TYPE}"
}

test_check_pkg_type_detects_http_package(){
    PKG_NAME="remote_pkg"
    URL="https://example.test/repo.git"
    NEW_PKG_LIST=""
    MOD_PKG_LIST=""

    FUNC_check_pkg_type >/dev/null

    assert_eq "http" "${PKG_TYPE}"
}

test_check_pkg_type_defaults_to_none(){
    PKG_NAME="unused_pkg"
    URL=""
    NEW_PKG_LIST=""
    MOD_PKG_LIST=""

    FUNC_check_pkg_type >/dev/null

    assert_eq "none" "${PKG_TYPE}"
}

test_case "empty OPENWRT_DIR sets RESULT_FALSE" test_empty_openwrt_dir_sets_false
test_case "existing OPENWRT_DIR sets RESULT_TRUE" test_existing_openwrt_dir_sets_true
test_case "missing OPENWRT_DIR sets RESULT_FALSE" test_missing_openwrt_dir_sets_false
test_case "new packages are discovered from feed workspace" test_get_new_pkg_list_reads_feed_workspace
test_case "modified packages are discovered from package makefiles" test_get_mod_pkg_list_reads_package_makefiles
test_case "package type detects new package" test_check_pkg_type_detects_new_package
test_case "package type detects modified package" test_check_pkg_type_detects_modified_package
test_case "package type detects http package" test_check_pkg_type_detects_http_package
test_case "package type defaults to none" test_check_pkg_type_defaults_to_none
finish_tests
