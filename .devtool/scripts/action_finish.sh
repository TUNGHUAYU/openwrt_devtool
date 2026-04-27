
function FUNC_finish_select_package(){
    local pkg_pattern=${1:-}
    local list="${NEW_PKG_LIST} ${MOD_PKG_LIST}"
    local matches=""
    local count=0
    local selected=""
    local p=""

    if [[ -n "${pkg_pattern}" ]]; then
        for p in ${list}
        do
            [[ "${p}" == *"${pkg_pattern}"* ]] && matches="${matches} ${p}"
        done
        list="${matches}"
    fi

    if [[ -z "${list}" ]]; then
        devtool_print "${LOG_ERRO}" "No matching package!!"
        RESULT=""
        return ${ERROR_NO_MATCHING_PKG}
    fi

    for p in ${list}
    do
        selected=${p}
        count=$((count + 1))
    done

    if [[ -z "${pkg_pattern}" ]] || [[ ${count} -gt 1 ]]; then
        FUNC_tui_select \
            "${list}" \
            --search-path "${DEVTOOL_DIR}/" \
            --message "Please select package to finish:" || return $?
        selected=${RESULT}
    fi

    RESULT=${selected}
}

function FUNC_finish_new_pkg(){
    local dry_run=${1:-}
    local src_makefile="${SELECTED_PKG_DIR}/Makefile"
    local dst_dir="${DEVTOOL_FINISHED_FEED_DIR}/${FEED_NAME}/${PKG_NAME}"
    local dst_makefile="${dst_dir}/Makefile"
    local src_source_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    local dst_source_dir="${DEVTOOL_FINISHED_SRC_DIR}/${PKG_NAME}"

    if [[ ! -f "${src_makefile}" ]]; then
        devtool_print "${LOG_ERRO}" "Missing package Makefile: %s" "${src_makefile}"
        return ${ERROR_FILE_NO_EXIST}
    fi
    if [[ ! -d "${src_source_dir}" ]]; then
        devtool_print "${LOG_ERRO}" "Missing source folder: %s" "${src_source_dir}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    if [[ "${dry_run}" == "--dry-run" ]]; then
        devtool_print "${LOG_CORE}" "DRY-RUN finish package: %s" "${PKG_NAME}"
        devtool_print "${LOG_CORE}" "package type: %s" "${DEVTOOL_PACKAGE_KIND}"
        devtool_print "${LOG_CORE}" "move package Makefile: %s -> %s" "${src_makefile}" "${dst_makefile}"
        devtool_print "${LOG_CORE}" "move source folder: %s -> %s" "${src_source_dir}" "${dst_source_dir}"
        return ${RESULT_OK}
    fi

    mkdir -p "${dst_dir}"
    mkdir -p "${DEVTOOL_FINISHED_SRC_DIR}"
    rm -rf "${dst_source_dir}"
    mv "${src_makefile}" "${dst_makefile}" || return $?
    mv "${src_source_dir}" "${dst_source_dir}" || return $?
    rm -rf "${SELECTED_PKG_DIR}"
    devtool_print "${LOG_CORE}" "%s" "${dst_makefile}"
    devtool_print "${LOG_CORE}" "%s" "${dst_source_dir}"
}

function FUNC_finish_generate_modify_patches(){
    local src_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    local patch_dir="${SELECTED_PKG_DIR}/patches"
    local tmp_patch_dir=""
    local base_ref=""
    local target_ref=${DEV_BRANCH:-dev}
    local status=0

    if [[ ! -f "${SELECTED_PKG_DIR}/Makefile" ]]; then
        devtool_print "${LOG_ERRO}" "Missing package Makefile: %s" "${SELECTED_PKG_DIR}/Makefile"
        return ${ERROR_FILE_NO_EXIST}
    fi
    if [[ ! -d "${src_dir}/.git" ]]; then
        devtool_print "${LOG_ERRO}" "Missing source git repository: %s" "${src_dir}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    FUNC_patch_read_base_ref "${SELECTED_PKG_DIR}/Makefile"
    base_ref=${RESULT}
    mkdir -p "${patch_dir}"
    tmp_patch_dir=$(mktemp -d "${patch_dir}/.devtool-patches.XXXXXX")
    FUNC_patch_generate "${src_dir}" "${tmp_patch_dir}" "${base_ref}" "${target_ref}"
    status=$?
    if [[ ${status} -ne 0 ]]; then
        rm -rf "${tmp_patch_dir}"
        return ${status}
    fi
    FUNC_patch_replace_dir "${patch_dir}" "${tmp_patch_dir}"
    rm -rf "${tmp_patch_dir}"
}

function FUNC_finish_restore_original_pkg(){
    local openwrt_pkg_dir="${OPENWRT_DIR}/package/${PKG_PATH}"
    local origin_pkg_dir="${DEVTOOL_WORKSPACE_ORIPKG_DIR}/${PKG_PATH}"

    rm -rf "${openwrt_pkg_dir}"
    mkdir -p "$(dirname "${openwrt_pkg_dir}")"
    if [[ -L "${origin_pkg_dir}" ]]; then
        ln -s "$(readlink "${origin_pkg_dir}")" "${openwrt_pkg_dir}"
    else
        cp -r "${origin_pkg_dir}" "${openwrt_pkg_dir}"
    fi
}

function FUNC_finish_modify_pkg(){
    local dry_run=${1:-}
    local openwrt_pkg_dir="${OPENWRT_DIR}/package/${PKG_PATH}"
    local patch_src_dir="${SELECTED_PKG_DIR}/patches"
    local patch_dst_dir="${openwrt_pkg_dir}/patches"

    if [[ "${dry_run}" == "--dry-run" ]]; then
        devtool_print "${LOG_CORE}" "DRY-RUN finish package: %s" "${PKG_NAME}"
        devtool_print "${LOG_CORE}" "package type: modify"
        devtool_print "${LOG_CORE}" "generate patches from package source commits"
        devtool_print "${LOG_CORE}" "restore OpenWrt package: %s" "${openwrt_pkg_dir}"
        devtool_print "${LOG_CORE}" "copy patches: %s -> %s" "${patch_src_dir}" "${patch_dst_dir}"
        devtool_print "${LOG_CORE}" "remove workspace package/source/origin entries"
        return ${RESULT_OK}
    fi

    FUNC_finish_generate_modify_patches || return $?
    FUNC_finish_restore_original_pkg || return $?

    mkdir -p "${patch_dst_dir}"
    if [[ -d "${patch_src_dir}" ]]; then
        find "${patch_dst_dir}" -maxdepth 1 -name "*.patch" -type f -delete
        cp -r "${patch_src_dir}/." "${patch_dst_dir}/"
    fi

    rm -rf "${SELECTED_PKG_DIR}"
    rm -rf "${DEVTOOL_WORKSPACE_ORIPKG_DIR:?}/${PKG_PATH}"
    rm -rf "${DEVTOOL_WORKSPACE_SRC_DIR:?}/${PKG_NAME}"
}

function FUNC_action_finish(){
    local pkg_pattern=${1:-}
    local dry_run=${2:-}

    FUNC_finish_select_package "${pkg_pattern}" || return $?
    SELECTED_PKG_DIR=${RESULT}
    PKG_NAME=${SELECTED_PKG_DIR##*/}

    if [[ "${SELECTED_PKG_DIR}" == "${DEVTOOL_WORKSPACE_PKG_DIR}"* ]]; then
        PKG_PATH=${SELECTED_PKG_DIR#"${DEVTOOL_WORKSPACE_PKG_DIR}/"}
    else
        PKG_PATH=${SELECTED_PKG_DIR#"${DEVTOOL_WORKSPACE_FEED_DIR}/"}
    fi

    FUNC_read_pkg_metadata "${SELECTED_PKG_DIR}"
    if [[ -z "${DEVTOOL_PACKAGE_KIND}" ]]; then
        if [[ "${SELECTED_PKG_DIR}" == "${DEVTOOL_WORKSPACE_PKG_DIR}"* ]]; then
            DEVTOOL_PACKAGE_KIND="modify"
        elif git -C "${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}" remote get-url origin >/dev/null 2>&1; then
            DEVTOOL_PACKAGE_KIND="new-git"
        else
            DEVTOOL_PACKAGE_KIND="new-sample"
        fi
    fi

    case "${DEVTOOL_PACKAGE_KIND}" in
        new-sample|new-git)
            FUNC_finish_new_pkg "${dry_run}"
            ;;
        modify)
            FUNC_finish_modify_pkg "${dry_run}"
            ;;
        *)
            devtool_print "${LOG_ERRO}" "ERROR: unsupported package type: %s" "${DEVTOOL_PACKAGE_KIND}"
            return ${ERROR_ILLEGAL_COMMAND}
            ;;
    esac
}
