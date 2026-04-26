#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"
source "${ROOT_DIR}/.devtool/scripts/action_abort.sh"

test_abort_mod_removes_origin_symlink_impl(){
    local tmpdir=$1
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/feed_prplos/demo_pkg"
    local original_target="${tmpdir}/openwrt/package/feeds/feed_prplos/demo_pkg.origin"
    local origin_link="${tmpdir}/workspace/PACKAGES_ORIGIN/feeds/feed_prplos/demo_pkg"
    local workspace_pkg="${tmpdir}/workspace/PACKAGES/feeds/feed_prplos/demo_pkg"
    local workspace_src="${tmpdir}/workspace/SOURCES/demo_pkg"

    mkdir -p "${original_target}" "${workspace_pkg}" "${workspace_src}" "${tmpdir}/openwrt/tmp/info"
    mkdir -p "$(dirname "${openwrt_pkg}")" "$(dirname "${origin_link}")"
    touch "${original_target}/Makefile" "${workspace_pkg}/Makefile"
    ln -s "${original_target}" "${origin_link}"
    ln -s "${workspace_pkg}" "${openwrt_pkg}"

    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_WORKSPACE_ORIPKG_DIR="${tmpdir}/workspace/PACKAGES_ORIGIN"
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="demo_pkg"

    FUNC_abort_mod_pkg_work >/dev/null

    [[ ! -L "${origin_link}" ]] &&
    [[ ! -e "${origin_link}" ]] &&
    [[ -L "${openwrt_pkg}" ]] &&
    assert_eq "${original_target}" "$(readlink "${openwrt_pkg}")"
}

test_abort_mod_removes_origin_symlink(){
    with_temp_repo test_abort_mod_removes_origin_symlink_impl
}

test_abort_mod_removes_broken_origin_symlink_impl(){
    local tmpdir=$1
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/feed_prplos/demo_pkg"
    local missing_target="${tmpdir}/openwrt/package/feeds/feed_prplos/missing-origin"
    local origin_link="${tmpdir}/workspace/PACKAGES_ORIGIN/feeds/feed_prplos/demo_pkg"
    local workspace_pkg="${tmpdir}/workspace/PACKAGES/feeds/feed_prplos/demo_pkg"
    local workspace_src="${tmpdir}/workspace/SOURCES/demo_pkg"

    mkdir -p "${workspace_pkg}" "${workspace_src}" "${tmpdir}/openwrt/tmp/info"
    mkdir -p "$(dirname "${openwrt_pkg}")" "$(dirname "${origin_link}")"
    touch "${workspace_pkg}/Makefile"
    ln -s "${missing_target}" "${origin_link}"
    ln -s "${workspace_pkg}" "${openwrt_pkg}"

    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_WORKSPACE_ORIPKG_DIR="${tmpdir}/workspace/PACKAGES_ORIGIN"
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="demo_pkg"

    FUNC_abort_mod_pkg_work >/dev/null

    [[ ! -L "${origin_link}" ]] &&
    [[ ! -e "${origin_link}" ]]
}

test_abort_mod_removes_broken_origin_symlink(){
    with_temp_repo test_abort_mod_removes_broken_origin_symlink_impl
}

test_case "abort modified package removes PACKAGE_ORIGIN symlink" test_abort_mod_removes_origin_symlink
test_case "abort modified package removes broken PACKAGE_ORIGIN symlink" test_abort_mod_removes_broken_origin_symlink
finish_tests
