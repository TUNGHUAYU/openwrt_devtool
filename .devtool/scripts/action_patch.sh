
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
        if [[ -n ${pkg_name_pattern} ]] && [[ -n ${MOD_PKG_LIST} ]]; then
            devtool_print "${LOG_WARN}" "No package matched \"%s\"; showing all modified packages." "${pkg_name_pattern}"
            match_list="${MOD_PKG_LIST}"
        else
            devtool_print "${LOG_ERRO}" "No matching modified package!!"
            RESULT=""
            return ${ERROR_NO_MATCHING_PKG}
        fi

    fi

    FUNC_tui_select \
    "${match_list}" \
    "${DEVTOOL_WORKSPACE_PKG_DIR}/" \
    "Please select package to patch:" \
    "" \
    "" \
    ""
}

function FUNC_patch_list_candidates(){
    local count=0
    local type="modify"
    local format="|%-03s|%-30s|%-10s|%-50s \n"
    local _format="|%-03d|%-30s|%-10s|%-50s \n"

    devtool_print "${LOG_CORE}" "${format}" "No." "PKG-NAME" "TYPE" "PKG-PATH"

    for p in ${MOD_PKG_LIST}
    do
        count=$(( count + 1 ))
        devtool_print "${LOG_CORE}" "${_format}" "${count}" "${p##*/}" "${type}" "${p/${DEVTOOL_DIR}\//}"
    done
}

function FUNC_patch_read_base_ref(){
    local makefile=$1

    RESULT=$(sed -E -n "s|^[[:space:]]*PKG_SOURCE_VERSION[[:space:]]*:?=[[:space:]]*(.*)|\1|p" "${makefile}" | head -n 1)
    [[ -z ${RESULT} ]] && RESULT="ref-base"
}

function FUNC_patch_generate(){
    local src_dir=$1
    local patch_dir=$2
    local base_ref=$3
    local target_ref=$4
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
        --start-number 1 \
        -o "${patch_dir}" \
        "${base_ref}..${target_ref}")
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
        fi
    done <<< "${output}"
}

function FUNC_patch_dirs_synced(){
    local current_dir=$1
    local generated_dir=$2
    local current_list=""
    local generated_list=""
    local patch_file=""
    local patch_name=""

    current_list=$(find "${current_dir}" -maxdepth 1 -name '*.patch' -type f -printf '%f\n' 2>/dev/null | sort)
    generated_list=$(find "${generated_dir}" -maxdepth 1 -name '*.patch' -type f -printf '%f\n' 2>/dev/null | sort)

    if [[ "${current_list}" != "${generated_list}" ]]; then
        RESULT=${RESULT_FALSE}
        return
    fi

    while IFS= read -r patch_name
    do
        [[ -n ${patch_name} ]] || continue
        if ! cmp -s "${current_dir}/${patch_name}" "${generated_dir}/${patch_name}"; then
            RESULT=${RESULT_FALSE}
            return
        fi
    done <<< "${generated_list}"

    RESULT=${RESULT_TRUE}
}

function FUNC_patch_replace_dir(){
    local current_dir=$1
    local generated_dir=$2
    local patch_file=""

    mkdir -p "${current_dir}"
    find "${current_dir}" -maxdepth 1 -name '*.patch' -type f -delete
    for patch_file in "${generated_dir}"/*.patch
    do
        [[ -e ${patch_file} ]] || continue
        cp "${patch_file}" "${current_dir}/"
    done
}

function FUNC_patch_print_final_paths(){
    local patch_dir=$1
    local patch_file=""

    for patch_file in "${patch_dir}"/*.patch
    do
        [[ -e ${patch_file} ]] || continue
        devtool_print "${LOG_CORE}" "%s" "${patch_file}"
    done
}

function FUNC_action_patch(){
    local pkg_name_pattern=$1
    local base_ref=${2:-}
    local target_ref=${DEV_BRANCH:-dev}
    local tmp_patch_dir=""
    local status=0

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

    if [[ -z ${base_ref} ]]; then
        FUNC_patch_read_base_ref "${DEVTOOL_PKG_DIR}/Makefile"
        base_ref=${RESULT}
    fi

    mkdir -p "${PATCH_DIR}"
    tmp_patch_dir=$(mktemp -d "${PATCH_DIR}/.devtool-patches.XXXXXX")
    FUNC_patch_generate "${DEVTOOL_SRC_DIR}" "${tmp_patch_dir}" "${base_ref}" "${target_ref}"
    status=$?
    if [[ ${status} -ne 0 ]]; then
        rm -rf "${tmp_patch_dir}"
        return ${status}
    fi

    FUNC_patch_dirs_synced "${PATCH_DIR}" "${tmp_patch_dir}"
    if [[ ${RESULT} == ${RESULT_TRUE} ]]; then
        rm -rf "${tmp_patch_dir}"
        devtool_print "${LOG_INFO}" "Patch files are synchronized."
        FUNC_patch_print_final_paths "${PATCH_DIR}"
        return ${RESULT_OK}
    fi

    FUNC_patch_replace_dir "${PATCH_DIR}" "${tmp_patch_dir}"
    rm -rf "${tmp_patch_dir}"
    FUNC_patch_print_final_paths "${PATCH_DIR}"
}
