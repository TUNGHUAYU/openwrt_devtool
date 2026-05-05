#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"
source "${ROOT_DIR}/.devtool/scripts/_core.sh"
source "${ROOT_DIR}/.devtool/scripts/action_patch.sh"
source "${ROOT_DIR}/.devtool/scripts/action_finish.sh"

create_finish_base_fixture(){
    local tmpdir=$1

    DEVTOOL_DIR="${tmpdir}/repo"
    OPENWRT_DIR="${tmpdir}/openwrt"
    FEED_NAME="feed_devtool"
    DEVTOOL_WORKSPACE_DIR="${tmpdir}/workspace"
    DEVTOOL_WORKSPACE_DEVELOPING_DIR="${DEVTOOL_WORKSPACE_DIR}/developing"
    DEVTOOL_WORKSPACE_FINISHED_DIR="${DEVTOOL_WORKSPACE_DIR}/finished"
    DEVTOOL_WORKSPACE_FEED_DIR="${DEVTOOL_WORKSPACE_DEVELOPING_DIR}/FEEDS"
    DEVTOOL_WORKSPACE_PKG_DIR="${DEVTOOL_WORKSPACE_DEVELOPING_DIR}/PACKAGES"
    DEVTOOL_WORKSPACE_ORIPKG_DIR="${DEVTOOL_WORKSPACE_DEVELOPING_DIR}/PACKAGES_ORIGIN"
    DEVTOOL_WORKSPACE_SRC_DIR="${DEVTOOL_WORKSPACE_DEVELOPING_DIR}/SOURCES"
    DEVTOOL_FINISHED_FEED_DIR="${DEVTOOL_WORKSPACE_FINISHED_DIR}/FEEDS"
    DEVTOOL_FINISHED_SRC_DIR="${DEVTOOL_WORKSPACE_FINISHED_DIR}/SOURCES"
    DEV_BRANCH="dev"
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    mkdir -p "${OPENWRT_DIR}/package/feeds/base" "${OPENWRT_DIR}/tmp/info"
}

create_finish_new_fixture(){
    local tmpdir=$1
    create_finish_base_fixture "${tmpdir}"

    local pkg_dir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg"
    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/demo_pkg"
    mkdir -p "${pkg_dir}/.devtool" "${src_dir}"
    printf "PKG_NAME:=demo_pkg\nPKG_SOURCE_URL:=file://%s\n" "${src_dir}" > "${pkg_dir}/Makefile"
    printf "demo source\n" > "${src_dir}/README.md"
    cat > "${pkg_dir}/.devtool/meta.conf" <<EOF
DEVTOOL_PACKAGE_KIND=new-sample
PKG_NAME=demo_pkg
PKG_PATH=${FEED_NAME}/demo_pkg
SOURCE_ORIGIN=sample:demo
EOF

    NEW_PKG_LIST="${pkg_dir}"
    MOD_PKG_LIST=""
}

create_finish_modify_fixture(){
    local tmpdir=$1
    create_finish_base_fixture "${tmpdir}"

    local pkg_path="feeds/base/demo_mod"
    local pkg_dir="${DEVTOOL_WORKSPACE_PKG_DIR}/${pkg_path}"
    local ori_dir="${DEVTOOL_WORKSPACE_ORIPKG_DIR}/${pkg_path}"
    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/demo_mod"
    local openwrt_pkg="${OPENWRT_DIR}/package/${pkg_path}"

    mkdir -p "${pkg_dir}/.devtool" "${ori_dir}" "${src_dir}" "$(dirname "${openwrt_pkg}")"
    printf "PKG_NAME:=demo_mod\nPKG_SOURCE_VERSION:=ref-base\n" > "${pkg_dir}/Makefile"
    printf "PKG_NAME:=demo_mod\n" > "${ori_dir}/Makefile"
    ln -sfn "${pkg_dir}" "${openwrt_pkg}"
    cat > "${pkg_dir}/.devtool/meta.conf" <<EOF
DEVTOOL_PACKAGE_KIND=modify
PKG_NAME=demo_mod
PKG_PATH=${pkg_path}
EOF

    git -C "${src_dir}" init -q
    git -C "${src_dir}" config user.name "Test User"
    git -C "${src_dir}" config user.email "test@example.com"
    printf "base\n" > "${src_dir}/feature.txt"
    git -C "${src_dir}" add feature.txt
    git -C "${src_dir}" commit -m "base commit" >/dev/null
    git -C "${src_dir}" branch ref-base
    git -C "${src_dir}" checkout -b dev ref-base >/dev/null 2>&1
    printf "base\nfeature\n" > "${src_dir}/feature.txt"
    git -C "${src_dir}" add feature.txt
    git -C "${src_dir}" commit -m "add feature" >/dev/null

    NEW_PKG_LIST=""
    MOD_PKG_LIST="${pkg_dir}"
}

test_finish_new_package_moves_makefile_to_finished_feed_impl(){
    local tmpdir=$1
    create_finish_new_fixture "${tmpdir}"

    FUNC_action_finish "demo_pkg" >/dev/null

    local finished_makefile="${DEVTOOL_FINISHED_FEED_DIR}/${FEED_NAME}/demo_pkg/Makefile"
    local workspace_pkg_dir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg"
    local workspace_makefile="${workspace_pkg_dir}/Makefile"
    local finished_source_file="${DEVTOOL_FINISHED_SRC_DIR}/demo_pkg/README.md"
    local workspace_source_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/demo_pkg"

    assert_contains "$(cat "${finished_makefile}")" "PKG_NAME:=demo_pkg" &&
    [[ ! -e "${workspace_makefile}" ]] &&
    [[ ! -e "${workspace_pkg_dir}" ]] &&
    assert_contains "$(cat "${finished_source_file}")" "demo source" &&
    [[ ! -e "${workspace_source_dir}" ]] &&
    [[ -d "${DEVTOOL_WORKSPACE_FEED_DIR}" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}" ]] &&
    [[ -d "${DEVTOOL_WORKSPACE_SRC_DIR}" ]]
}

test_finish_new_package_moves_makefile_to_finished_feed(){
    with_temp_repo test_finish_new_package_moves_makefile_to_finished_feed_impl
}

test_finish_new_package_dry_run_does_not_move_makefile_impl(){
    local tmpdir=$1
    create_finish_new_fixture "${tmpdir}"

    local output
    output=$(FUNC_action_finish "demo_pkg" "--dry-run")

    local finished_makefile="${DEVTOOL_FINISHED_FEED_DIR}/${FEED_NAME}/demo_pkg/Makefile"
    local workspace_makefile="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg/Makefile"
    local finished_source_dir="${DEVTOOL_FINISHED_SRC_DIR}/demo_pkg"
    local workspace_source_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/demo_pkg"

    assert_contains "${output}" "DRY-RUN finish package: demo_pkg" &&
    assert_contains "${output}" "package type: new-sample" &&
    assert_contains "${output}" "move package Makefile:" &&
    assert_contains "${output}" "move source folder:" &&
    [[ ! -e "${finished_makefile}" ]] &&
    [[ -e "${workspace_makefile}" ]] &&
    [[ ! -e "${finished_source_dir}" ]] &&
    [[ -e "${workspace_source_dir}" ]] &&
    [[ -d "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}" ]]
}

test_finish_new_package_dry_run_does_not_move_makefile(){
    with_temp_repo test_finish_new_package_dry_run_does_not_move_makefile_impl
}

test_finish_modify_package_restores_openwrt_and_moves_patches_impl(){
    local tmpdir=$1
    create_finish_modify_fixture "${tmpdir}"

    FUNC_action_finish "demo_mod" >/dev/null

    local openwrt_pkg="${OPENWRT_DIR}/package/feeds/base/demo_mod"
    local patch_file
    patch_file=$(find "${openwrt_pkg}/patches" -maxdepth 1 -name '001-*.patch' -type f)

    [[ ! -L "${openwrt_pkg}" ]] &&
    assert_contains "$(cat "${openwrt_pkg}/Makefile")" "PKG_NAME:=demo_mod" &&
    assert_contains "${patch_file}" "001-add-feature.patch" &&
    [[ ! -e "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/base/demo_mod" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_ORIPKG_DIR}/feeds/base/demo_mod" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_SRC_DIR}/demo_mod" ]] &&
    [[ -d "${DEVTOOL_WORKSPACE_PKG_DIR}" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds" ]] &&
    [[ -d "${DEVTOOL_WORKSPACE_ORIPKG_DIR}" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_ORIPKG_DIR}/feeds" ]] &&
    [[ -d "${DEVTOOL_WORKSPACE_SRC_DIR}" ]]
}

test_finish_new_package_without_metadata_uses_fallback_impl(){
    local tmpdir=$1
    create_finish_new_fixture "${tmpdir}"
    rm -rf "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/demo_pkg/.devtool"

    FUNC_action_finish "demo_pkg" >/dev/null

    local finished_makefile="${DEVTOOL_FINISHED_FEED_DIR}/${FEED_NAME}/demo_pkg/Makefile"
    assert_contains "$(cat "${finished_makefile}")" "PKG_NAME:=demo_pkg"
}

test_finish_new_package_without_metadata_uses_fallback(){
    with_temp_repo test_finish_new_package_without_metadata_uses_fallback_impl
}

test_finish_modify_package_restores_openwrt_and_moves_patches(){
    with_temp_repo test_finish_modify_package_restores_openwrt_and_moves_patches_impl
}

test_finish_no_pattern_shows_menu_impl(){
    local tmpdir=$1
    create_finish_new_fixture "${tmpdir}"

    local output
    output=$(printf "1\n" | FUNC_action_finish "")

    assert_contains "${output}" "Please select package to finish:" &&
    assert_contains "${output}" "demo_pkg"
}

test_finish_no_pattern_shows_menu(){
    with_temp_repo test_finish_no_pattern_shows_menu_impl
}

test_case "finish new package moves Makefile to finished feed" test_finish_new_package_moves_makefile_to_finished_feed
test_case "finish new package dry-run does not move Makefile" test_finish_new_package_dry_run_does_not_move_makefile
test_case "finish modify package restores OpenWrt and moves patches" test_finish_modify_package_restores_openwrt_and_moves_patches
test_case "finish new package works without feed metadata" test_finish_new_package_without_metadata_uses_fallback
test_case "finish without pattern shows package menu" test_finish_no_pattern_shows_menu
finish_tests
