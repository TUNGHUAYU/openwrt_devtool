#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"

test_makefile_templates_exist(){
    local dir="${ROOT_DIR}/.devtool/ref-Makefile"

    [[ -f "${dir}/Makefile.prebuilt-artifacts.generic" ]] &&
    [[ -f "${dir}/Makefile.python3-module.generic" ]] &&
    [[ -f "${dir}/Makefile.meson.generic" ]] &&
    [[ -f "${dir}/Makefile.make.generic" ]] &&
    [[ -f "${dir}/Makefile.files-package.generic" ]]
}

test_makefile_templates_use_expected_openwrt_helpers(){
    local dir="${ROOT_DIR}/.devtool/ref-Makefile"

    assert_contains "$(cat "${dir}/Makefile.prebuilt-artifacts.generic")" "Build/Compile:=:" &&
    assert_contains "$(cat "${dir}/Makefile.python3-module.generic")" "python3-package.mk" &&
    assert_contains "$(cat "${dir}/Makefile.meson.generic")" 'include $(INCLUDE_DIR)/meson.mk' &&
    assert_contains "$(cat "${dir}/Makefile.make.generic")" '$(TARGET_CC)' &&
    assert_contains "$(cat "${dir}/Makefile.files-package.generic")" "Build/Compile"
}

test_demo_sources_exist(){
    local dir="${ROOT_DIR}/.devtool/ref-sources"

    [[ -f "${dir}/prebuilt_hello-artifacts/usr/bin/hello-prebuilt" ]] &&
    [[ -f "${dir}/python3_hello-module/hello_openwrt/__init__.py" ]] &&
    [[ -f "${dir}/meson_hello-world/meson.build" ]] &&
    [[ -f "${dir}/make_hello-world/Makefile" ]] &&
    [[ -f "${dir}/files_hello-package/files/usr/bin/hello-files" ]] &&
    [[ -f "${dir}/autotools_hello-world/configure.ac" ]]
}

test_case "new Makefile templates exist" test_makefile_templates_exist
test_case "new Makefile templates use expected OpenWrt helpers" test_makefile_templates_use_expected_openwrt_helpers
test_case "demo sources exist for new templates" test_demo_sources_exist
finish_tests
