#!/bin/bash

set -u

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
status=0

bash -n \
    "${ROOT_DIR}/devtool.sh" \
    "${ROOT_DIR}/.devtool/scripts/_core.sh" \
    "${ROOT_DIR}/.devtool/scripts/_init.sh" \
    "${ROOT_DIR}/.devtool/scripts/_utils.sh" \
    "${ROOT_DIR}/.devtool/scripts/action_abort.sh" \
    "${ROOT_DIR}/.devtool/scripts/action_list.sh" \
    "${ROOT_DIR}/.devtool/scripts/action_modify.sh" \
    "${ROOT_DIR}/.devtool/scripts/action_new.sh" || status=$?

for test_file in "${ROOT_DIR}"/tests/test_*.sh; do
    bash "${test_file}" || status=$?
done

exit "${status}"
