
function FUNC_patch_select_pkg(){
    local pkg_name_pattern=$1
    local match_list=""
    local match_count=0
    local pkg_name=""

    for p in ${MOD_PKG_LIST}
    do
        pkg_name=${p##*/}
        if [[ "${pkg_name}" =~ ${pkg_name_pattern} ]] || [[ "${p}" =~ ${pkg_name_pattern} ]]; then
            match_list="${match_list} ${p}"
            match_count=$((match_count + 1))
        fi
    done

    if [[ ${match_count} -eq 0 ]]; then
        devtool_print "${LOG_ERRO}" "No matching modified package!!"
        RESULT=""
        return ${ERROR_NO_MATCHING_PKG}
    fi

    if [[ ${match_count} -eq 1 ]]; then
        RESULT="${match_list# }"
        return ${RESULT_OK}
    fi

    FUNC_tui_select \
    "${match_list}" \
    "${DEVTOOL_WORKSPACE_PKG_DIR}/" \
    "Please select package to patch:" \
    "" \
    "" \
    ""
}

function FUNC_patch_next_start_number(){
    local patch_dir=$1
    local max=0
    local patch_file=""
    local patch_name=""
    local patch_num=""

    for patch_file in "${patch_dir}"/[0-9][0-9][0-9]-*.patch
    do
        [[ -e ${patch_file} ]] || continue
        patch_name=${patch_file##*/}
        patch_num=${patch_name%%-*}
        if (( 10#${patch_num} > max )); then
            max=$((10#${patch_num}))
        fi
    done

    RESULT=$((max + 1))
}

function FUNC_patch_generate(){
    local src_dir=$1
    local patch_dir=$2
    local base_ref=$3
    local start_number=$4
    local output=""
    local status=0
    local generated_file=""
    local patch_name=""
    local patch_num=""
    local patch_subject=""
    local normalized_name=""
    local normalized_file=""

    mkdir -p "${patch_dir}"
    output=$(git -C "${src_dir}" format-patch \
        --start-number "${start_number}" \
        -o "${patch_dir}" \
        "${base_ref}..HEAD")
    status=$?
    [[ ${status} -ne 0 ]] && return ${status}

    while IFS= read -r generated_file
    do
        [[ -f ${generated_file} ]] || continue
        patch_name=${generated_file##*/}
        patch_num=${patch_name%%-*}
        patch_subject=${patch_name#*-}

        if [[ ${patch_num} =~ ^[0-9][0-9][0-9][0-9]$ ]] && (( 10#${patch_num} < 1000 )); then
            normalized_name=$(printf "%03d-%s" "$((10#${patch_num}))" "${patch_subject}")
            normalized_file="${patch_dir}/${normalized_name}"
            mv "${generated_file}" "${normalized_file}"
            echo "${normalized_file}"
        else
            echo "${generated_file}"
        fi
    done <<< "${output}"
}

function FUNC_action_patch(){
    local pkg_name_pattern=$1
    local base_ref=${2:-ref-base}

    if [[ -z ${base_ref} ]]; then
        devtool_print "${LOG_ERRO}" "Missing base ref"
        return ${ERROR_NO_BASE_REF}
    fi

    FUNC_patch_select_pkg "${pkg_name_pattern}" || return $?

    OPENWRT_PKG_DIR=${RESULT}
    PKG_NAME=${OPENWRT_PKG_DIR##*/}
    PKG_PATH=${OPENWRT_PKG_DIR#${DEVTOOL_WORKSPACE_PKG_DIR}/}
    DEVTOOL_PKG_DIR="${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"
    DEVTOOL_SRC_DIR="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    PATCH_DIR="${DEVTOOL_PKG_DIR}/patches"

    if [[ ! -f "${DEVTOOL_PKG_DIR}/Makefile" ]]; then
        devtool_print "${LOG_ERRO}" "Missing package Makefile: ${DEVTOOL_PKG_DIR}/Makefile"
        return ${ERROR_FILE_NO_EXIST}
    fi

    if [[ ! -d "${DEVTOOL_SRC_DIR}/.git" ]]; then
        devtool_print "${LOG_ERRO}" "Missing source git repository: ${DEVTOOL_SRC_DIR}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    FUNC_patch_next_start_number "${PATCH_DIR}"
    FUNC_patch_generate "${DEVTOOL_SRC_DIR}" "${PATCH_DIR}" "${base_ref}" "${RESULT}"
}
