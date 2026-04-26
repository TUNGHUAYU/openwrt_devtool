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

test_create_workspace_src_dir_from_vcs_download_impl(){
    local tmpdir=$1
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/feed_prplos/demo_pkg"
    local src_dir="${tmpdir}/workspace/SOURCES/demo_pkg"
    local fixture_archive="${tmpdir}/demo_pkg-1.0.tar.gz"
    mkdir -p "${openwrt_pkg}" "${tmpdir}/openwrt"
    create_test_tarball "${tmpdir}" "${fixture_archive}" "demo_pkg-1.0"
    cat > "${openwrt_pkg}/Makefile" <<'EOF'
PKG_NAME:=demo_pkg
PKG_VERSION:=1.0
PKG_SOURCE:=demo_pkg-1.0.tar.gz
PKG_SOURCE_URL:=https://example.test/demo_pkg.git
PKG_SOURCE_PROTO:=git
PKG_SOURCE_VERSION:=v1.0
PKG_HASH:=skip
EOF
    cat > "${tmpdir}/openwrt/Makefile" <<EOF
.PHONY: package/feeds/feed_prplos/demo_pkg/download
package/feeds/feed_prplos/demo_pkg/download:
	mkdir -p "\$(CURDIR)/dl"
	cp "${fixture_archive}" "\$(CURDIR)/dl/demo_pkg-1.0.tar.gz"
EOF

    OPENWRT_PKG_DIR="${openwrt_pkg}"
    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_DIR="${tmpdir}/devtool"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="demo_pkg"
    PKG_PATH="feeds/feed_prplos/demo_pkg"

    FUNC_create_workspace_src_dir >/dev/null 2>&1

    local current_branch
    current_branch=$(git -C "${src_dir}" branch --show-current)

    assert_eq "dev" "${current_branch}" &&
    git -C "${src_dir}" rev-parse ref-base >/dev/null &&
    git -C "${src_dir}" rev-parse dev >/dev/null &&
    assert_contains "$(cat "${src_dir}/source.txt")" "prepared" &&
    [[ -f "${OPENWRT_DIR}/dl/demo_pkg-1.0.tar.gz" ]]
}

test_create_workspace_src_dir_from_vcs_download(){
    with_temp_repo test_create_workspace_src_dir_from_vcs_download_impl
}

test_redirect_src_pkg_url_uses_ref_base_impl(){
    local tmpdir=$1
    local pkg_dir="${tmpdir}/workspace/PACKAGES/feeds/feed_prplos/demo_pkg"
    mkdir -p "${pkg_dir}"
    cat > "${pkg_dir}/Makefile" <<'EOF'
PKG_NAME:=demo_pkg
PKG_VERSION:=1.0
PKG_RELEASE:=1
PKG_SOURCE:=demo_pkg-1.0.tar.gz
PKG_SOURCE_URL:=https://example.test/demo_pkg
PKG_SOURCE_VERSION:=v1.0
PKG_HASH:=skip
PKG_INSTALL:=1
PKG_FIXUP:=autoreconf
PKG_BUILD_FLAGS:=lto
PKG_LICENSE:=MIT
EOF

    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/PACKAGES"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_PATH="feeds/feed_prplos/demo_pkg"
    PKG_NAME="demo_pkg"
    PKG_SOURCE_URL_GIT_BRANCH="v1.0"

    FUNC_redirect_src_pkg_url >/dev/null

    local content
    content=$(cat "${pkg_dir}/Makefile")
    assert_contains "${content}" "PKG_SOURCE_VERSION:=ref-base" &&
    assert_contains "${content}" "PKG_VERSION:=v1.0" &&
    assert_contains "${content}" "# PKG_SOURCE:=demo_pkg-1.0.tar.gz" &&
    assert_contains "${content}" "# PKG_SOURCE_URL:=https://example.test/demo_pkg" &&
    assert_contains "${content}" "# PKG_HASH:=skip" &&
    assert_contains "${content}" "PKG_INSTALL:=1" &&
    assert_contains "${content}" "PKG_FIXUP:=autoreconf" &&
    assert_contains "${content}" "PKG_BUILD_FLAGS:=lto" &&
    assert_contains "${content}" "PKG_LICENSE:=MIT" &&
    [[ "${content}" != *"# PKG_INSTALL:=1"* ]] &&
    [[ "${content}" != *"# PKG_FIXUP:=autoreconf"* ]] &&
    [[ "${content}" != *"# PKG_BUILD_FLAGS:=lto"* ]]
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

create_test_tarball(){
    local tmpdir=$1
    local archive_path=$2
    local top_dir=${3:-libcap-ng-0.8.4}
    local source_dir="${tmpdir}/archive-src/${top_dir}"

    mkdir -p "${source_dir}"
    printf "prepared\n" > "${source_dir}/source.txt"
    tar -czf "${archive_path}" -C "${tmpdir}/archive-src" "${top_dir}"
}

create_fake_download_pl(){
    local openwrt_dir=$1
    local fixture_archive=$2

    mkdir -p "${openwrt_dir}/scripts" "${openwrt_dir}/staging_dir/host/bin"
    printf "{}\n" > "${openwrt_dir}/scripts/projectsmirrors.json"
    cat > "${openwrt_dir}/staging_dir/host/bin/mkhash" <<'EOF'
#!/bin/bash
cat >/dev/null
printf "skip\n"
EOF
    chmod +x "${openwrt_dir}/staging_dir/host/bin/mkhash"
    cat > "${openwrt_dir}/scripts/download.pl" <<EOF
#!/bin/bash
set -e
[[ "\${DOWNLOAD_CHECK_CERTIFICATE:-}" == "n" ]]
[[ "\${TOPDIR:-}" == "${openwrt_dir}" ]]
[[ "\${MKHASH:-}" == "${openwrt_dir}/staging_dir/host/bin/mkhash" ]]
[[ -f "\$(dirname "\$0")/projectsmirrors.json" ]]
dl_dir=\$1
file=\$2
mkdir -p "\${dl_dir}"
cp "${fixture_archive}" "\${dl_dir}/\${file}"
EOF
    chmod +x "${openwrt_dir}/scripts/download.pl"
}

test_create_workspace_src_dir_from_tarball_download_impl(){
    local tmpdir=$1
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/packages/libcap-ng"
    local src_dir="${tmpdir}/workspace/SOURCES/libcap-ng"
    local fixture_archive="${tmpdir}/libcap-ng-0.8.4.tar.gz"
    mkdir -p "${openwrt_pkg}"
    create_test_tarball "${tmpdir}" "${fixture_archive}"
    create_fake_download_pl "${tmpdir}/openwrt" "${fixture_archive}"
    cat > "${openwrt_pkg}/Makefile" <<'EOF'
PKG_NAME:=libcap-ng
PKG_VERSION:=0.8.4
PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_URL:=https://people.redhat.com/sgrubb/libcap-ng
PKG_HASH:=skip
EOF

    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_DIR="${tmpdir}/devtool"
    OPENWRT_PKG_DIR="${openwrt_pkg}"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="libcap-ng"
    PKG_PATH="feeds/packages/libcap-ng"
    FUNC_create_workspace_src_dir >/dev/null 2>&1

    local current_branch
    current_branch=$(git -C "${src_dir}" branch --show-current)

    assert_eq "dev" "${current_branch}" &&
    git -C "${src_dir}" rev-parse ref-base >/dev/null &&
    git -C "${src_dir}" rev-parse dev >/dev/null &&
    assert_contains "$(cat "${src_dir}/source.txt")" "prepared" &&
    [[ -L "${DEVTOOL_DIR}/.devtool/openwrt/utils/download.pl" ]] &&
    assert_eq "${OPENWRT_DIR}/scripts/download.pl" "$(readlink "${DEVTOOL_DIR}/.devtool/openwrt/utils/download.pl")" &&
    [[ -L "${DEVTOOL_DIR}/.devtool/openwrt/utils/projectsmirrors.json" ]] &&
    assert_eq "${OPENWRT_DIR}/scripts/projectsmirrors.json" "$(readlink "${DEVTOOL_DIR}/.devtool/openwrt/utils/projectsmirrors.json")" &&
    [[ -f "${OPENWRT_DIR}/dl/libcap-ng-0.8.4.tar.gz" ]]
}

test_create_workspace_src_dir_from_tarball_download(){
    with_temp_repo test_create_workspace_src_dir_from_tarball_download_impl
}

test_tarball_source_url_file_overrides_download_name_impl(){
    local tmpdir=$1
    local openwrt_pkg="${tmpdir}/openwrt/package/feeds/packages/libcap-ng"
    local src_dir="${tmpdir}/workspace/SOURCES/libcap-ng"
    local fixture_archive="${tmpdir}/libcap-ng-release.tar.gz"
    mkdir -p "${openwrt_pkg}"
    create_test_tarball "${tmpdir}" "${fixture_archive}"
    create_fake_download_pl "${tmpdir}/openwrt" "${fixture_archive}"
    cat > "${openwrt_pkg}/Makefile" <<'EOF'
PKG_NAME:=libcap-ng
PKG_VERSION:=0.8.4
PKG_SOURCE:=ignored-local-name.tar.gz
PKG_SOURCE_URL_FILE:=libcap-ng-release.tar.gz
PKG_SOURCE_URL:=https://example.test/download
PKG_HASH:=skip
EOF

    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_DIR="${tmpdir}/devtool"
    OPENWRT_PKG_DIR="${openwrt_pkg}"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/SOURCES"
    PKG_NAME="libcap-ng"
    PKG_PATH="feeds/packages/libcap-ng"
    FUNC_create_workspace_src_dir >/dev/null 2>&1

    [[ -f "${OPENWRT_DIR}/dl/libcap-ng-release.tar.gz" ]] &&
    assert_contains "$(cat "${src_dir}/source.txt")" "prepared"
}

test_tarball_source_url_file_overrides_download_name(){
    with_temp_repo test_tarball_source_url_file_overrides_download_name_impl
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
    [[ ! -e "${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}" ]] &&
    [[ ! -e "${DEVTOOL_PKG_DIR}" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_ORIPKG_DIR}/${PKG_PATH}" ]] &&
    assert_contains "$(cat "${pkg_dir}/Makefile")" "PKG_SOURCE_URL:=https://example.test/failpkg"
}

test_modify_stops_before_mutation_when_source_setup_fails(){
    with_temp_repo test_modify_stops_before_mutation_when_source_setup_fails_impl
}

test_case "modify VCS source uses OpenWrt download archive" test_create_workspace_src_dir_from_vcs_download
test_case "modify Makefile redirect uses ref-base" test_redirect_src_pkg_url_uses_ref_base
test_case "modify dry-run prints plan without mutating" test_modify_dry_run_prints_plan_without_mutating
test_case "modify parser detects tarball source" test_parse_url_detects_tarball_source
test_case "modify tarball download creates ref-base and dev branches" test_create_workspace_src_dir_from_tarball_download
test_case "modify tarball uses PKG_SOURCE_URL_FILE as download name" test_tarball_source_url_file_overrides_download_name
test_case "modify source setup failure leaves package unmodified" test_modify_stops_before_mutation_when_source_setup_fails
finish_tests
