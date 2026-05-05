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

test_link_openwrt_codebase_creates_symlink_impl(){
    local tmpdir=$1
    DEVTOOL_DIR="${tmpdir}/devtool"
    OPENWRT_DIR="${tmpdir}/openwrt"
    mkdir -p "${DEVTOOL_DIR}" "${OPENWRT_DIR}"

    FUNC_link_openwrt_codebase >/dev/null || return $?

    [[ -L "${DEVTOOL_DIR}/codebase" ]] &&
    assert_eq "${OPENWRT_DIR}" "$(readlink "${DEVTOOL_DIR}/codebase")"
}

test_link_openwrt_codebase_creates_symlink(){
    with_temp_repo test_link_openwrt_codebase_creates_symlink_impl
}

test_link_openwrt_codebase_updates_existing_symlink_impl(){
    local tmpdir=$1
    DEVTOOL_DIR="${tmpdir}/devtool"
    OPENWRT_DIR="${tmpdir}/openwrt-new"
    mkdir -p "${DEVTOOL_DIR}" "${tmpdir}/openwrt-old" "${OPENWRT_DIR}"
    ln -s "${tmpdir}/openwrt-old" "${DEVTOOL_DIR}/codebase"

    FUNC_link_openwrt_codebase >/dev/null || return $?

    assert_eq "${OPENWRT_DIR}" "$(readlink "${DEVTOOL_DIR}/codebase")"
}

test_link_openwrt_codebase_updates_existing_symlink(){
    with_temp_repo test_link_openwrt_codebase_updates_existing_symlink_impl
}

test_link_openwrt_codebase_skips_non_symlink_impl(){
    local tmpdir=$1
    DEVTOOL_DIR="${tmpdir}/devtool"
    OPENWRT_DIR="${tmpdir}/openwrt"
    mkdir -p "${DEVTOOL_DIR}/codebase" "${OPENWRT_DIR}"

    FUNC_link_openwrt_codebase >/dev/null || return $?

    [[ -d "${DEVTOOL_DIR}/codebase" ]] &&
    [[ ! -L "${DEVTOOL_DIR}/codebase" ]]
}

test_link_openwrt_codebase_skips_non_symlink(){
    with_temp_repo test_link_openwrt_codebase_skips_non_symlink_impl
}

test_path_config_uses_developing_and_finished_layout(){
    local old_devtool_dir=${DEVTOOL_DIR:-}
    local old_openwrt_dir=${OPENWRT_DIR:-}

    DEVTOOL_DIR="/repo"
    source "${ROOT_DIR}/.devtool/configs/path.conf"

    local status=0
    assert_eq "/repo/workspace/developing/FEEDS" "${DEVTOOL_WORKSPACE_FEED_DIR}" || status=$?
    assert_eq "/repo/workspace/developing/SOURCES" "${DEVTOOL_WORKSPACE_SRC_DIR}" || status=$?
    assert_eq "/repo/workspace/developing/PACKAGES" "${DEVTOOL_WORKSPACE_PKG_DIR}" || status=$?
    assert_eq "/repo/workspace/developing/PACKAGES_ORIGIN" "${DEVTOOL_WORKSPACE_ORIPKG_DIR}" || status=$?
    assert_eq "/repo/workspace/finished/FEEDS" "${DEVTOOL_FINISHED_FEED_DIR}" || status=$?
    assert_eq "/repo/workspace/finished/SOURCES" "${DEVTOOL_FINISHED_SRC_DIR}" || status=$?

    DEVTOOL_DIR=${old_devtool_dir}
    OPENWRT_DIR=${old_openwrt_dir}
    return ${status}
}

test_get_new_pkg_list_reads_feed_workspace_impl(){
    local tmpdir=$1
    DEVTOOL_WORKSPACE_FEED_DIR="${tmpdir}/workspace/developing/FEEDS"
    FEED_NAME="feed_devtool"
    mkdir -p "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg"
    touch "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg/Makefile"

    FUNC_get_new_pkg_list

    assert_eq "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg" "${NEW_PKG_LIST}"
}

test_get_new_pkg_list_reads_feed_workspace(){
    with_temp_repo test_get_new_pkg_list_reads_feed_workspace_impl
}

test_get_new_pkg_list_ignores_metadata_dirs_impl(){
    local tmpdir=$1
    DEVTOOL_WORKSPACE_FEED_DIR="${tmpdir}/workspace/developing/FEEDS"
    FEED_NAME="feed_devtool"
    mkdir -p "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg/.devtool"
    touch "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg/Makefile"

    FUNC_get_new_pkg_list

    assert_eq "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg" "${NEW_PKG_LIST}" &&
    [[ "${NEW_PKG_LIST}" != *".devtool"* ]]
}

test_get_new_pkg_list_ignores_metadata_dirs(){
    with_temp_repo test_get_new_pkg_list_ignores_metadata_dirs_impl
}

test_get_new_pkg_list_ignores_finished_metadata_only_package_impl(){
    local tmpdir=$1
    DEVTOOL_WORKSPACE_FEED_DIR="${tmpdir}/workspace/developing/FEEDS"
    FEED_NAME="feed_devtool"
    mkdir -p "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg/.devtool"

    FUNC_get_new_pkg_list

    assert_eq "" "${NEW_PKG_LIST}"
}

test_get_new_pkg_list_ignores_finished_metadata_only_package(){
    with_temp_repo test_get_new_pkg_list_ignores_finished_metadata_only_package_impl
}

test_get_mod_pkg_list_reads_package_makefiles_impl(){
    local tmpdir=$1
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/developing/PACKAGES"
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
    NEW_PKG_LIST="/repo/workspace/developing/FEEDS/feed_devtool/demo_pkg"
    MOD_PKG_LIST=""

    FUNC_check_pkg_type >/dev/null

    assert_eq "new" "${PKG_TYPE}"
}

test_check_pkg_type_detects_modified_package(){
    PKG_NAME="existing_pkg"
    URL=""
    NEW_PKG_LIST=""
    MOD_PKG_LIST="/repo/workspace/developing/PACKAGES/feeds/base/existing_pkg"

    FUNC_check_pkg_type >/dev/null

    assert_eq "modify" "${PKG_TYPE}"
}

test_check_pkg_type_detects_remote_git_url(){
    PKG_NAME="remote_pkg"
    URL="https://example.test/repo.git"
    NEW_PKG_LIST=""
    MOD_PKG_LIST=""

    FUNC_check_pkg_type >/dev/null

    assert_eq "remote-git" "${PKG_TYPE}"
}

test_check_pkg_type_detects_ssh_remote_git_url(){
    PKG_NAME="remote_pkg"
    URL="git@example.test:repo.git"
    NEW_PKG_LIST=""
    MOD_PKG_LIST=""

    FUNC_check_pkg_type >/dev/null

    assert_eq "remote-git" "${PKG_TYPE}"
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
test_case "codebase symlink is created for available OpenWrt tree" test_link_openwrt_codebase_creates_symlink
test_case "codebase symlink is updated when OpenWrt tree changes" test_link_openwrt_codebase_updates_existing_symlink
test_case "codebase symlink skips non-symlink path" test_link_openwrt_codebase_skips_non_symlink
test_case "path config uses developing and finished workspace layout" test_path_config_uses_developing_and_finished_layout
test_case "new packages are discovered from feed workspace" test_get_new_pkg_list_reads_feed_workspace
test_case "new package discovery ignores metadata directories" test_get_new_pkg_list_ignores_metadata_dirs
test_case "new package discovery ignores metadata-only finished packages" test_get_new_pkg_list_ignores_finished_metadata_only_package
test_case "modified packages are discovered from package makefiles" test_get_mod_pkg_list_reads_package_makefiles
test_case "package type detects new package" test_check_pkg_type_detects_new_package
test_case "package type detects modified package" test_check_pkg_type_detects_modified_package
test_case "package type detects remote git URL" test_check_pkg_type_detects_remote_git_url
test_case "package type detects ssh remote git URL" test_check_pkg_type_detects_ssh_remote_git_url
test_case "package type defaults to none" test_check_pkg_type_defaults_to_none
finish_tests
