#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"
source "${ROOT_DIR}/.devtool/scripts/_core.sh"
source "${ROOT_DIR}/.devtool/scripts/action_modify.sh"

create_remote_repo(){
    local repo_dir=$1

    git -C "${repo_dir}" init -q
    git -C "${repo_dir}" config user.name "Test User"
    git -C "${repo_dir}" config user.email "test@example.com"
    printf "base\n" > "${repo_dir}/source.txt"
    git -C "${repo_dir}" add source.txt
    git -C "${repo_dir}" commit -m "base commit" >/dev/null
    git -C "${repo_dir}" tag v1.0
}

test_create_workspace_src_dir_creates_ref_base_and_dev_impl(){
    local tmpdir=$1
    local remote_repo="${tmpdir}/origin.git"
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/feed_prplos/demo_pkg"
    local src_dir="${tmpdir}/workspace/SOURCES/demo_pkg"
    mkdir -p "${remote_repo}" "${openwrt_pkg}"
    create_remote_repo "${remote_repo}"
    printf "PKG_SOURCE_URL:=%s\nPKG_SOURCE_VERSION:=v1.0\n" "${remote_repo}" > "${openwrt_pkg}/Makefile"

    OPENWRT_PKG_DIR="${openwrt_pkg}"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="demo_pkg"

    FUNC_create_workspace_src_dir >/dev/null 2>&1

    local current_branch
    local ref_base_rev
    local dev_rev
    local expected_rev
    current_branch=$(git -C "${src_dir}" branch --show-current)
    ref_base_rev=$(git -C "${src_dir}" rev-parse ref-base)
    dev_rev=$(git -C "${src_dir}" rev-parse dev)
    expected_rev=$(git -C "${remote_repo}" rev-parse v1.0)

    assert_eq "dev" "${current_branch}" &&
    assert_eq "${expected_rev}" "${ref_base_rev}" &&
    assert_eq "${expected_rev}" "${dev_rev}"
}

test_create_workspace_src_dir_creates_ref_base_and_dev(){
    with_temp_repo test_create_workspace_src_dir_creates_ref_base_and_dev_impl
}

test_redirect_src_pkg_url_uses_ref_base_impl(){
    local tmpdir=$1
    local pkg_dir="${tmpdir}/workspace/PACKAGES/feeds/feed_prplos/demo_pkg"
    mkdir -p "${pkg_dir}"
    printf "PKG_NAME:=demo_pkg\nPKG_SOURCE_VERSION:=v1.0\n" > "${pkg_dir}/Makefile"

    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_PATH="feeds/feed_prplos/demo_pkg"
    PKG_NAME="demo_pkg"
    PKG_SOURCE_URL_GIT_BRANCH="v1.0"

    FUNC_redirect_src_pkg_url >/dev/null

    local content
    content=$(cat "${pkg_dir}/Makefile")
    assert_contains "${content}" "PKG_SOURCE_VERSION:=ref-base" &&
    assert_contains "${content}" "PKG_VERSION:=v1.0"
}

test_redirect_src_pkg_url_uses_ref_base(){
    with_temp_repo test_redirect_src_pkg_url_uses_ref_base_impl
}

test_modify_dry_run_prints_plan_without_mutating_impl(){
    local tmpdir=$1
    local pkg_dir="${tmpdir}/openwrt/package/feeds/feed_prplos/demo_pkg"
    mkdir -p "${pkg_dir}"
    printf "PKG_SOURCE_URL:=git@example.test:demo.git\nPKG_SOURCE_VERSION:=v1.0\n" > "${pkg_dir}/Makefile"

    OPENWRT_PKG_DIR="${pkg_dir}"
    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_ORIPKG_DIR="${tmpdir}/workspace/PACKAGES_ORIGIN"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="demo_pkg"
    PKG_PATH="feeds/feed_prplos/demo_pkg"
    DEVTOOL_PKG_DIR="${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"

    local output
    output=$(FUNC_modify_dry_run_plan)

    assert_contains "${output}" "DRY-RUN modify package: demo_pkg" &&
    assert_contains "${output}" "create ref-base branch at v1.0" &&
    assert_contains "${output}" "checkout dev branch from ref-base" &&
    assert_contains "${output}" "rewrite Makefile with PKG_SOURCE_VERSION:=ref-base" &&
    [[ ! -e "${DEVTOOL_PKG_DIR}" ]]
}

test_modify_dry_run_prints_plan_without_mutating(){
    with_temp_repo test_modify_dry_run_prints_plan_without_mutating_impl
}

test_parse_url_detects_tarball_source_impl(){
    local tmpdir=$1
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/packages/libcap-ng"
    mkdir -p "${openwrt_pkg}"
    cat > "${openwrt_pkg}/Makefile" <<'EOF'
PKG_NAME:=libcap-ng
PKG_VERSION:=0.8.4
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://people.redhat.com/sgrubb/libcap-ng
EOF

    OPENWRT_PKG_DIR="${openwrt_pkg}"

    FUNC_parse_url "https://people.redhat.com/sgrubb/libcap-ng"

    assert_eq "tarball" "${PKG_SOURCE_URL_TYPE}" &&
    assert_eq "https://people.redhat.com/sgrubb/libcap-ng" "${PKG_SOURCE_URL_TARBALL}" &&
    assert_eq "0.8.4" "${PKG_SOURCE_URL_GIT_BRANCH}"
}

test_parse_url_detects_tarball_source(){
    with_temp_repo test_parse_url_detects_tarball_source_impl
}

test_create_workspace_src_dir_from_tarball_prepare_impl(){
    local tmpdir=$1
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/packages/libcap-ng"
    local src_dir="${tmpdir}/workspace/SOURCES/libcap-ng"
    local fake_bin="${tmpdir}/bin"
    mkdir -p "${openwrt_pkg}" "${fake_bin}"
    cat > "${openwrt_pkg}/Makefile" <<'EOF'
PKG_NAME:=libcap-ng
PKG_VERSION:=0.8.4
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://people.redhat.com/sgrubb/libcap-ng
EOF
    cat > "${fake_bin}/make" <<'EOF'
#!/bin/bash
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-C" ]]; then
        openwrt_dir=$2
        shift 2
        continue
    fi
    shift
done
mkdir -p "${openwrt_dir}/build_dir/target-test/libcap-ng-0.8.4"
printf "prepared\n" > "${openwrt_dir}/build_dir/target-test/libcap-ng-0.8.4/source.txt"
EOF
    chmod +x "${fake_bin}/make"

    OPENWRT_DIR="${tmpdir}/openwrt"
    OPENWRT_PKG_DIR="${openwrt_pkg}"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="libcap-ng"
    PKG_PATH="feeds/packages/libcap-ng"
    PATH="${fake_bin}:${PATH}" FUNC_create_workspace_src_dir >/dev/null 2>&1

    local current_branch
    current_branch=$(git -C "${src_dir}" branch --show-current)

    assert_eq "dev" "${current_branch}" &&
    git -C "${src_dir}" rev-parse ref-base >/dev/null &&
    git -C "${src_dir}" rev-parse dev >/dev/null &&
    assert_contains "$(cat "${src_dir}/source.txt")" "prepared"
}

test_create_workspace_src_dir_from_tarball_prepare(){
    with_temp_repo test_create_workspace_src_dir_from_tarball_prepare_impl
}

test_modify_stops_before_mutation_when_source_setup_fails_impl(){
    local tmpdir=$1
    local pkg_dir="${tmpdir}/openwrt/package/feeds/packages/failpkg"
    mkdir -p "${pkg_dir}"
    cat > "${pkg_dir}/Makefile" <<'EOF'
PKG_NAME:=failpkg
PKG_VERSION:=1.0
PKG_SOURCE:=failpkg-1.0.tar.gz
PKG_SOURCE_URL:=https://example.test/failpkg
EOF

    OPENWRT_PKG_DIR="${pkg_dir}"
    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_ORIPKG_DIR="${tmpdir}/workspace/PACKAGES_ORIGIN"
    PKG_NAME="failpkg"
    PKG_PATH="feeds/packages/failpkg"
    DEVTOOL_PKG_DIR="${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"

    FUNC_create_workspace_src_dir >/dev/null 2>&1
    local status=$?

    assert_status "${ERROR_FILE_NO_EXIST}" "${status}" &&
    [[ ! -L "${pkg_dir}" ]] &&
    [[ ! -e "${DEVTOOL_PKG_DIR}" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_ORIPKG_DIR}/${PKG_PATH}" ]] &&
    assert_contains "$(cat "${pkg_dir}/Makefile")" "PKG_SOURCE_URL:=https://example.test/failpkg"
}

test_modify_stops_before_mutation_when_source_setup_fails(){
    with_temp_repo test_modify_stops_before_mutation_when_source_setup_fails_impl
}

test_case "modify source setup creates ref-base and dev branches" test_create_workspace_src_dir_creates_ref_base_and_dev
test_case "modify Makefile redirect uses ref-base" test_redirect_src_pkg_url_uses_ref_base
test_case "modify dry-run prints plan without mutating" test_modify_dry_run_prints_plan_without_mutating
test_case "modify parser detects tarball source" test_parse_url_detects_tarball_source
test_case "modify tarball source setup creates ref-base and dev branches" test_create_workspace_src_dir_from_tarball_prepare
test_case "modify source setup failure leaves package unmodified" test_modify_stops_before_mutation_when_source_setup_fails
finish_tests
