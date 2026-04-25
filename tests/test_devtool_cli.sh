#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
source "${ROOT_DIR}/tests/lib/assertions.sh"

test_bash_devtool_sh_resolves_repo_dir(){
    local output
    output=$(cd "${ROOT_DIR}" && bash -x devtool.sh patch demo_plugin test 2>&1)

    assert_contains "${output}" "+ DEVTOOL_DIR=${ROOT_DIR}" &&
    assert_contains "${output}" "+ source ${ROOT_DIR}/.devtool/scripts/action_patch.sh"
}

test_case "bash devtool.sh resolves DEVTOOL_DIR to repo root" test_bash_devtool_sh_resolves_repo_dir
finish_tests
