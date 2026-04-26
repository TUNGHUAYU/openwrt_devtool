#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"
source "${ROOT_DIR}/.devtool/scripts/action_patch.sh"

create_patch_fixture(){
    local tmpdir=$1
    local pkg_dir="${tmpdir}/workspace/PACKAGES/feeds/feed_prplos/demo_pkg"
    local src_dir="${tmpdir}/workspace/SOURCES/demo_pkg"

    mkdir -p "${pkg_dir}" "${src_dir}"
    touch "${pkg_dir}/Makefile"

    git -C "${src_dir}" init -q
    git -C "${src_dir}" config user.name "Test User"
    git -C "${src_dir}" config user.email "test@example.com"
    printf "base\n" > "${src_dir}/feature.txt"
    git -C "${src_dir}" add feature.txt
    git -C "${src_dir}" commit -m "base commit" >/dev/null
    BASE_REF=$(git -C "${src_dir}" rev-parse HEAD)
    git -C "${src_dir}" branch ref-base "${BASE_REF}"
    printf "base\nfeature\n" > "${src_dir}/feature.txt"
    git -C "${src_dir}" add feature.txt
    git -C "${src_dir}" commit -m "add feature" >/dev/null

    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    MOD_PKG_LIST="${pkg_dir}"
    PKG_PATTERN="demo_pkg"
}

test_patch_action_generates_openwrt_patch_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"

    FUNC_action_patch "${PKG_PATTERN}" "${BASE_REF}" >/dev/null

    local patch_file
    patch_file=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '001-*.patch' -type f)
    local patch_content
    patch_content=$(cat "${patch_file}")

    assert_contains "${patch_file}" "001-add-feature.patch" &&
    assert_contains "${patch_content}" "Subject: [PATCH] add feature" &&
    assert_contains "${patch_content}" "+feature"
}

test_patch_action_generates_openwrt_patch(){
    with_temp_repo test_patch_action_generates_openwrt_patch_impl
}

test_patch_action_appends_after_existing_patch_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"
    mkdir -p "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches"
    touch "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches/001-existing.patch"

    FUNC_action_patch "${PKG_PATTERN}" "${BASE_REF}" >/dev/null

    local patch_file
    patch_file=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '002-*.patch' -type f)

    assert_contains "${patch_file}" "002-add-feature.patch"
}

test_patch_action_appends_after_existing_patch(){
    with_temp_repo test_patch_action_appends_after_existing_patch_impl
}

test_patch_action_requires_source_git_repo_impl(){
    local tmpdir=$1
    local pkg_dir="${tmpdir}/workspace/PACKAGES/feeds/feed_prplos/demo_pkg"
    mkdir -p "${pkg_dir}"
    touch "${pkg_dir}/Makefile"
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    MOD_PKG_LIST="${pkg_dir}"

    FUNC_action_patch "demo_pkg" "HEAD" >/dev/null
    local status=$?

    assert_status "${ERROR_FILE_NO_EXIST}" "${status}"
}

test_patch_action_requires_source_git_repo(){
    with_temp_repo test_patch_action_requires_source_git_repo_impl
}

test_patch_action_defaults_to_ref_base_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"

    FUNC_action_patch "${PKG_PATTERN}" >/dev/null

    local patch_file
    patch_file=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '001-*.patch' -type f)

    assert_contains "${patch_file}" "001-add-feature.patch"
}

test_patch_action_defaults_to_ref_base(){
    with_temp_repo test_patch_action_defaults_to_ref_base_impl
}

test_case "patch action generates OpenWrt patch" test_patch_action_generates_openwrt_patch
test_case "patch action appends after existing patches" test_patch_action_appends_after_existing_patch
test_case "patch action requires source git repo" test_patch_action_requires_source_git_repo
test_case "patch action defaults base ref to ref-base" test_patch_action_defaults_to_ref_base
finish_tests
