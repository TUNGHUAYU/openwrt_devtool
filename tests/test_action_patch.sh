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
    printf "PKG_SOURCE_VERSION:=ref-base\n" > "${pkg_dir}/Makefile"

    git -C "${src_dir}" init -q
    git -C "${src_dir}" config user.name "Test User"
    git -C "${src_dir}" config user.email "test@example.com"
    printf "base\n" > "${src_dir}/feature.txt"
    git -C "${src_dir}" add feature.txt
    git -C "${src_dir}" commit -m "base commit" >/dev/null
    BASE_REF=$(git -C "${src_dir}" rev-parse HEAD)
    git -C "${src_dir}" branch ref-base "${BASE_REF}"
    git -C "${src_dir}" checkout -b dev ref-base >/dev/null 2>&1
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

    local output
    output=$(FUNC_action_patch "${PKG_PATTERN}" "${BASE_REF}")

    local patch_file
    patch_file=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '001-*.patch' -type f)
    local patch_content
    patch_content=$(cat "${patch_file}")

    assert_contains "${patch_file}" "001-add-feature.patch" &&
    assert_contains "${output}" "${patch_file}" &&
    [[ "${output}" != *".devtool-patches"* ]] &&
    assert_contains "${patch_content}" "Subject: [PATCH] add feature" &&
    assert_contains "${patch_content}" "+feature"
}

test_patch_action_generates_openwrt_patch(){
    with_temp_repo test_patch_action_generates_openwrt_patch_impl
}

test_patch_action_replaces_stale_existing_patch_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"
    mkdir -p "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches"
    touch "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches/001-existing.patch"
    touch "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches/README"

    FUNC_action_patch "${PKG_PATTERN}" "${BASE_REF}" >/dev/null

    local patch_dir="${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches"
    local patch_file
    patch_file=$(find "${patch_dir}" -maxdepth 1 -name '001-*.patch' -type f)

    assert_contains "${patch_file}" "001-add-feature.patch" &&
    [[ ! -e "${patch_dir}/001-existing.patch" ]] &&
    [[ -e "${patch_dir}/README" ]]
}

test_patch_action_replaces_stale_existing_patch(){
    with_temp_repo test_patch_action_replaces_stale_existing_patch_impl
}

test_patch_action_rerun_does_not_duplicate_patch_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"

    FUNC_action_patch "${PKG_PATTERN}" "${BASE_REF}" >/dev/null
    FUNC_action_patch "${PKG_PATTERN}" "${BASE_REF}" >/dev/null

    local patch_count
    patch_count=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '*.patch' -type f | wc -l)

    assert_eq "1" "${patch_count}"
}

test_patch_action_rerun_does_not_duplicate_patch(){
    with_temp_repo test_patch_action_rerun_does_not_duplicate_patch_impl
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

test_patch_action_uses_makefile_source_version_as_base_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"
    local pkg_dir="${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg"
    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/demo_pkg"

    git -C "${src_dir}" checkout ref-base >/dev/null 2>&1
    git -C "${src_dir}" checkout -b custom-base >/dev/null 2>&1
    printf "base\ncustom\n" > "${src_dir}/feature.txt"
    git -C "${src_dir}" add feature.txt
    git -C "${src_dir}" commit -m "custom base change" >/dev/null
    git -C "${src_dir}" branch -f dev >/dev/null
    printf "PKG_SOURCE_VERSION:=custom-base\n" > "${pkg_dir}/Makefile"

    FUNC_action_patch "${PKG_PATTERN}" >/dev/null

    local patch_file
    patch_file=$(find "${pkg_dir}/patches" -maxdepth 1 -name '*.patch' -type f)

    assert_eq "" "${patch_file}"
}

test_patch_action_uses_makefile_source_version_as_base(){
    with_temp_repo test_patch_action_uses_makefile_source_version_as_base_impl
}

test_patch_action_uses_dev_branch_when_head_elsewhere_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"
    local pkg_dir="${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg"
    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/demo_pkg"

    git -C "${src_dir}" checkout ref-base >/dev/null 2>&1

    FUNC_action_patch "${PKG_PATTERN}" >/dev/null

    local patch_file
    patch_file=$(find "${pkg_dir}/patches" -maxdepth 1 -name '001-*.patch' -type f)

    assert_contains "${patch_file}" "001-add-feature.patch"
}

test_patch_action_uses_dev_branch_when_head_elsewhere(){
    with_temp_repo test_patch_action_uses_dev_branch_when_head_elsewhere_impl
}

test_patch_action_menu_selects_package_without_pattern_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"

    local output
    output=$(printf "1\n" | FUNC_action_patch "")

    local patch_file
    patch_file=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '001-*.patch' -type f)

    assert_contains "${output}" "Please select package to patch:" &&
    assert_contains "${output}" "Select: feeds/feed_prplos/demo_pkg" &&
    assert_contains "${output}" "${patch_file}" &&
    assert_contains "${patch_file}" "001-add-feature.patch"
}

test_patch_action_menu_selects_package_without_pattern(){
    with_temp_repo test_patch_action_menu_selects_package_without_pattern_impl
}

test_patch_action_menu_selects_single_package_without_pattern_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"

    local output
    output=$(printf "1\n" | FUNC_action_patch "")

    assert_contains "${output}" "Please select package to patch:" &&
    assert_contains "${output}" "demo_pkg"
}

test_patch_action_menu_selects_single_package_without_pattern(){
    with_temp_repo test_patch_action_menu_selects_single_package_without_pattern_impl
}

test_patch_action_menu_selects_single_pattern_match_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"

    local output
    output=$(printf "1\n" | FUNC_action_patch "demo")

    local patch_file
    patch_file=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '001-*.patch' -type f)

    assert_contains "${output}" "Please select package to patch:" &&
    assert_contains "${output}" "demo_pkg" &&
    assert_contains "${output}" "${patch_file}" &&
    assert_contains "${patch_file}" "001-add-feature.patch"
}

test_patch_action_menu_selects_single_pattern_match(){
    with_temp_repo test_patch_action_menu_selects_single_pattern_match_impl
}

test_patch_action_zero_match_pattern_shows_all_modified_impl(){
    local tmpdir=$1
    create_patch_fixture "${tmpdir}"

    local output
    output=$(printf "1\n" | FUNC_action_patch "does-not-match")

    local patch_file
    patch_file=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}/feeds/feed_prplos/demo_pkg/patches" -maxdepth 1 -name '001-*.patch' -type f)

    assert_contains "${output}" "No package matched \"does-not-match\"; showing all modified packages." &&
    assert_contains "${output}" "Please select package to patch:" &&
    assert_contains "${output}" "demo_pkg" &&
    assert_contains "${output}" "${patch_file}" &&
    assert_contains "${patch_file}" "001-add-feature.patch"
}

test_patch_action_zero_match_pattern_shows_all_modified(){
    with_temp_repo test_patch_action_zero_match_pattern_shows_all_modified_impl
}

test_patch_action_no_modified_packages_errors(){
    DEVTOOL_WORKSPACE_PKG_DIR="/repo/workspace/PACKAGES"
    MOD_PKG_LIST=""

    FUNC_action_patch "does-not-match" >/dev/null
    local status=$?

    assert_status "${ERROR_NO_MATCHING_PKG}" "${status}"
}

test_patch_action_menu_displays_modified_candidates(){
    DEVTOOL_DIR="/repo"
    DEVTOOL_WORKSPACE_PKG_DIR="/repo/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_SRC_DIR="/repo/workspace/SOURCES"
    MOD_PKG_LIST="/repo/workspace/PACKAGES/feeds/feed_prplos/pkg_one /repo/workspace/PACKAGES/feeds/feed_lcm/pkg_two"

    local output
    output=$(printf "2\n" | FUNC_action_patch "" 2>&1 || true)

    assert_contains "${output}" "PKG-NAME" &&
    assert_contains "${output}" "pkg_one" &&
    assert_contains "${output}" "pkg_two" &&
    assert_contains "${output}" "\${search_path}/feeds/feed_prplos/pkg_one" &&
    assert_contains "${output}" "\${search_path}/feeds/feed_lcm/pkg_two" &&
    assert_contains "${output}" "Select: feeds/feed_lcm/pkg_two"
}

test_devtool_patch_without_pattern_reaches_candidate_listing(){
    local output
    output=$(cd "${ROOT_DIR}" && bash -x devtool.sh patch 2>&1 || true)

    assert_contains "${output}" "+ source ${ROOT_DIR}/.devtool/scripts/action_patch.sh" &&
    [[ "${output}" != *"Usage: ./devtool.sh <command> [options]"* ]]
}

test_case "patch action generates OpenWrt patch" test_patch_action_generates_openwrt_patch
test_case "patch action replaces stale existing patches" test_patch_action_replaces_stale_existing_patch
test_case "patch action rerun does not duplicate patch" test_patch_action_rerun_does_not_duplicate_patch
test_case "patch action requires source git repo" test_patch_action_requires_source_git_repo
test_case "patch action defaults base ref to ref-base" test_patch_action_defaults_to_ref_base
test_case "patch action uses Makefile source version as base" test_patch_action_uses_makefile_source_version_as_base
test_case "patch action uses dev branch when HEAD is elsewhere" test_patch_action_uses_dev_branch_when_head_elsewhere
test_case "patch action menu selects package without pattern" test_patch_action_menu_selects_package_without_pattern
test_case "patch action menu selects single package without pattern" test_patch_action_menu_selects_single_package_without_pattern
test_case "patch action menu selects single pattern match" test_patch_action_menu_selects_single_pattern_match
test_case "patch action zero-match pattern shows all modified packages" test_patch_action_zero_match_pattern_shows_all_modified
test_case "patch action no modified packages errors" test_patch_action_no_modified_packages_errors
test_case "patch action menu displays modified candidates" test_patch_action_menu_displays_modified_candidates
test_case "devtool patch without pattern reaches candidate listing" test_devtool_patch_without_pattern_reaches_candidate_listing
finish_tests
