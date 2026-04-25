#!/bin/bash

TEST_TOTAL=${TEST_TOTAL:-0}
TEST_FAILURES=${TEST_FAILURES:-0}

test_case(){
    local name=$1
    local fn=$2

    TEST_TOTAL=$((TEST_TOTAL + 1))
    if "${fn}"; then
        printf "PASS %s\n" "${name}"
    else
        local status=$?
        TEST_FAILURES=$((TEST_FAILURES + 1))
        printf "FAIL %s (status %s)\n" "${name}" "${status}" >&2
    fi
}

assert_eq(){
    local expected=$1
    local actual=$2

    if [[ "${expected}" != "${actual}" ]]; then
        printf "Expected: %s\nActual:   %s\n" "${expected}" "${actual}" >&2
        return 1
    fi
}

assert_contains(){
    local haystack=$1
    local needle=$2

    if [[ "${haystack}" != *"${needle}"* ]]; then
        printf "Expected output to contain: %s\nActual output:\n%s\n" "${needle}" "${haystack}" >&2
        return 1
    fi
}

assert_status(){
    local expected=$1
    local actual=$2

    if [[ "${expected}" != "${actual}" ]]; then
        printf "Expected status: %s\nActual status:   %s\n" "${expected}" "${actual}" >&2
        return 1
    fi
}

with_temp_repo(){
    local callback=$1
    local tmpdir

    tmpdir=$(mktemp -d)
    "${callback}" "${tmpdir}"
    local status=$?
    rm -rf "${tmpdir}"
    return "${status}"
}

finish_tests(){
    if [[ "${TEST_FAILURES}" -ne 0 ]]; then
        printf "%s/%s tests failed\n" "${TEST_FAILURES}" "${TEST_TOTAL}" >&2
        exit 1
    fi
}
