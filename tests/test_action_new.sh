#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"
source "${ROOT_DIR}/.devtool/configs/core.conf"
source "${ROOT_DIR}/.devtool/scripts/_utils.sh"
source "${ROOT_DIR}/.devtool/scripts/_core.sh"
source "${ROOT_DIR}/.devtool/scripts/action_new.sh"

create_remote_git_repo(){
    local tmpdir=$1
    local src="${tmpdir}/remote-src"
    local bare="${tmpdir}/remote.git"

    mkdir -p "${src}"
    git -C "${src}" init -q
    git -C "${src}" config user.name "Test User"
    git -C "${src}" config user.email "test@example.com"
    printf "remote source\n" > "${src}/README.md"
    git -C "${src}" add README.md
    git -C "${src}" commit -m "initial remote source" >/dev/null
    git -C "${src}" clone --bare . "${bare}" >/dev/null 2>&1

    RESULT="${bare}"
}

create_openwrt_feed_fixture(){
    local tmpdir=$1

    OPENWRT_DIR="${tmpdir}/openwrt"
    DEVTOOL_DIR="${ROOT_DIR}"
    DEVTOOL_WORKSPACE_SRC_DIR="${tmpdir}/workspace/developing/SOURCES"
    DEVTOOL_WORKSPACE_FEED_DIR="${tmpdir}/workspace/developing/FEEDS"
    DEVTOOL_WORKSPACE_PKG_DIR="${tmpdir}/workspace/developing/PACKAGES"
    DEVTOOL_WORKSPACE_ORIPKG_DIR="${tmpdir}/workspace/developing/PACKAGES_ORIGIN"
    FEED_NAME="feed_devtool"
    CATEGORY="devtool-pkg"
    SUBMENU="misc"
    TITLE="short description here"
    DESCRIPTION="long description here"
    NEW_PKG_LIST=""
    MOD_PKG_LIST=""
    LOG_LEVEL=${LOG_CORE}
    VERBOSE=0

    mkdir -p "${OPENWRT_DIR}/scripts" "${OPENWRT_DIR}/feeds"
    printf "src-git packages https://example.test/packages.git\n" > "${OPENWRT_DIR}/feeds.conf"
    cat > "${OPENWRT_DIR}/scripts/feeds" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${OPENWRT_DIR}/scripts/feeds"
}

test_new_action_remote_file_url_creates_dev_source_impl(){
    local tmpdir=$1
    create_openwrt_feed_fixture "${tmpdir}"
    create_remote_git_repo "${tmpdir}"
    local remote_url="file://${RESULT}"

    printf "1\n" | FUNC_action_new "remote_pkg" "${remote_url}" >/dev/null 2>&1

    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/remote_pkg"
    local pkg_dir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/remote_pkg"
    local branch
    branch=$(git -C "${src_dir}" branch --show-current)
    local makefile
    makefile=$(cat "${pkg_dir}/Makefile")

    assert_eq "dev" "${branch}" &&
    assert_contains "${makefile}" "PKG_NAME:=remote_pkg" &&
    assert_contains "${makefile}" "PKG_SOURCE_URL:=file://${src_dir}" &&
    assert_contains "${makefile}" "PKG_SOURCE_VERSION:=dev" &&
    assert_contains "$(cat "${src_dir}/README.md")" "remote source"
}

test_new_action_remote_file_url_creates_dev_source(){
    with_temp_repo test_new_action_remote_file_url_creates_dev_source_impl
}

test_new_action_invalid_remote_cleans_workspace_impl(){
    local tmpdir=$1
    create_openwrt_feed_fixture "${tmpdir}"
    local bad_url="file://${tmpdir}/missing.git"

    FUNC_action_new "bad_remote" "${bad_url}" >/dev/null
    local status=$?

    assert_status "${ERROR_NOT_GIT_REPO}" "${status}" &&
    [[ ! -e "${DEVTOOL_WORKSPACE_SRC_DIR}/bad_remote" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/bad_remote" ]]
}

test_new_action_invalid_remote_cleans_workspace(){
    with_temp_repo test_new_action_invalid_remote_cleans_workspace_impl
}

test_new_action_remote_setup_failure_cleans_workspace_impl(){
    local tmpdir=$1
    create_openwrt_feed_fixture "${tmpdir}"
    create_remote_git_repo "${tmpdir}"
    local remote_url="file://${RESULT}"

    FUNC_create_new_pkg_source_remote(){
        mkdir -p "${DEVTOOL_SRC_DIR}"
        return 42
    }

    printf "1\n" | FUNC_action_new "failing_remote" "${remote_url}" >/dev/null 2>&1
    local status=$?

    assert_status 42 "${status}" &&
    [[ ! -e "${DEVTOOL_WORKSPACE_SRC_DIR}/failing_remote" ]] &&
    [[ ! -e "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/failing_remote" ]]
}

test_new_action_remote_setup_failure_cleans_workspace(){
    with_temp_repo test_new_action_remote_setup_failure_cleans_workspace_impl
}

test_new_action_generates_prebuilt_template_impl(){
    local tmpdir=$1
    create_openwrt_feed_fixture "${tmpdir}"

    local prebuilt_index
    prebuilt_index=$(find -L "${ROOT_DIR}/.devtool/ref-Makefile" -iname "Makefile*" | sort | nl -ba | awk '/Makefile.prebuilt-artifacts.generic/ {print $1}')
    local source_index
    source_index=$(find -L "${ROOT_DIR}/.devtool/ref-sources" -mindepth 1 -maxdepth 1 -type d | sort | nl -ba | awk '/prebuilt_hello-artifacts/ {print $1}')

    printf "%s\n%s\n" "${prebuilt_index}" "${source_index}" | FUNC_action_new "prebuilt_demo" >/dev/null 2>&1

    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/prebuilt_demo"
    local pkg_dir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/prebuilt_demo"
    local makefile
    makefile=$(cat "${pkg_dir}/Makefile")

    assert_contains "${makefile}" "PKG_NAME:=prebuilt_demo" &&
    assert_contains "${makefile}" "Build/Compile:=:" &&
    assert_contains "${makefile}" '$(CP) $(PKG_BUILD_DIR)/usr/* $(1)/usr/' &&
    [[ ! -e "${pkg_dir}/.devtool" ]] &&
    [[ -x "${src_dir}/usr/bin/hello-prebuilt" ]]
}

test_new_action_generates_prebuilt_template(){
    with_temp_repo test_new_action_generates_prebuilt_template_impl
}

test_new_action_generates_python3_template_impl(){
    local tmpdir=$1
    create_openwrt_feed_fixture "${tmpdir}"

    local python_index
    python_index=$(find -L "${ROOT_DIR}/.devtool/ref-Makefile" -iname "Makefile*" | sort | nl -ba | awk '/Makefile.python3-module.generic/ {print $1}')
    local source_index
    source_index=$(find -L "${ROOT_DIR}/.devtool/ref-sources" -mindepth 1 -maxdepth 1 -type d | sort | nl -ba | awk '/python3_hello-module/ {print $1}')

    printf "%s\n%s\n" "${python_index}" "${source_index}" | FUNC_action_new "python_demo" >/dev/null 2>&1

    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/python_demo"
    local pkg_dir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/python_demo"
    local makefile
    makefile=$(cat "${pkg_dir}/Makefile")

    assert_contains "${makefile}" "PKG_NAME:=python_demo" &&
    assert_contains "${makefile}" "PYTHON3_PKG_SETUP_DIR:=" &&
    assert_contains "${makefile}" "PYTHON3_PKG_WHEEL_NAME:=hello_openwrt" &&
    assert_contains "${makefile}" '$(eval $(call Py3Package,$(PKG_NAME)))' &&
    [[ ! -e "${pkg_dir}/.devtool" ]] &&
    [[ -f "${src_dir}/pyproject.toml" ]] &&
    [[ -f "${src_dir}/hello_openwrt/__init__.py" ]]
}

test_new_action_generates_python3_template(){
    with_temp_repo test_new_action_generates_python3_template_impl
}

test_case "new action remote file URL creates dev source" test_new_action_remote_file_url_creates_dev_source
test_case "new action invalid remote cleans workspace" test_new_action_invalid_remote_cleans_workspace
test_case "new action remote setup failure cleans workspace" test_new_action_remote_setup_failure_cleans_workspace
test_case "new action generates prebuilt template and source" test_new_action_generates_prebuilt_template
test_case "new action generates python3 template and source" test_new_action_generates_python3_template
finish_tests
