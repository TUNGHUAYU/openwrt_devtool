
# check if OPENWRT_DIR variable exist
# usage : FUNC_exist_openwrt_dir 

FUNC_exist_openwrt_dir(){
    if [[ -z ${OPENWRT_DIR} ]]; then
        devtool_print $LOG_INFO "OPENWRT_DIR is unset"
        RESULT=${RESULT_FALSE}
    else
        devtool_print $LOG_INFO "OPENWRT_DIR=${OPENWRT_DIR}"
        RESULT=${RESULT_TRUE}
    fi
}


# check if the path is legal openwrt dir
FUNC_is_openwrt_dir(){

    # check if the path is legal
    if [[ ! -d ${OPENWRT_DIR} ]]; then
        devtool_print "$LOG_ERRO" "illegal OPENWRT DIR path: ${OPENWRT_DIR}"
        RESULT=${RESULT_FALSE}
    else
        devtool_print "$LOG_INFO" "legal OPENWRT DIR path: ${OPENWRT_DIR}"
        RESULT=${RESULT_TRUE}
    fi
}

# new file in ${DEVTOOL_DIR}/.openwrt_dir to record the openwrt workspace
FUNC_remember_openwrt_dir(){

    local _OPENWRT_DIR=$(cat ${DEVTOOL_DIR}/.openwrt_dir 2>/dev/null)

    if [[ ${_OPENWRT_DIR} != ${OPENWRT_DIR} ]]; then
        echo "Update ${DEVTOOL_DIR}/.openwrt_dir"
        echo "${OPENWRT_DIR}" > ${DEVTOOL_DIR}/.openwrt_dir
    fi
}


function FUNC_get_new_pkg_list(){
    local new_pkg_list=""
    local new_pkg_workdir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/"

    if [[ -d ${new_pkg_workdir} ]]; then
        new_pkg_list=$(find "${new_pkg_workdir}" -mindepth 2 -maxdepth 2 -iname Makefile -type f | sed 's|/Makefile$||')
    fi

    # export to global variable 
    NEW_PKG_LIST="${new_pkg_list}"
}

function FUNC_get_mod_pkg_list(){
    local mod_pkg_list=""
    local mod_pkg_workdir="${DEVTOOL_WORKSPACE_PKG_DIR}"

    if [[ -d ${mod_pkg_workdir}  ]]; then
        mod_pkg_makefile_list=$(find ${mod_pkg_workdir} -iname makefile -type f)
        mod_pkg_list=${mod_pkg_makefile_list//\/Makefile}
    fi

    # export to global variable
    MOD_PKG_LIST="${mod_pkg_list}"
}

function FUNC_check_pkg_type(){
    local url=$URL
    local pkg_name=""
    echo $pkg_name
    PKG_TYPE="none"

    # check if package is in ${NEW_PKG_LIST}
    for p in ${NEW_PKG_LIST}
    do
        pkg_name=${p##*/}
        if [[ "${pkg_name}" == "${PKG_NAME}" ]]; then
            PKG_TYPE="new"
            return
        fi
    done

    # check if package is in ${MOD_PKG_LIST}
    for p in ${MOD_PKG_LIST}
    do
        pkg_name=${p##*/}
        if [[ "${pkg_name}" == "${PKG_NAME}" ]]; then
            PKG_TYPE="modify"
            return
        fi
    done

    # check if package source comes from a remote/local Git URL
    if [[ -n "${url}" ]]; then
        PKG_TYPE="remote-git"
        return
    fi
}

function FUNC_write_pkg_metadata(){
    local path=$1
    local kind=$2
    local pkg_path=${3:-}
    local source_origin=${4:-}
    local meta_dir="${path}/.devtool"

    mkdir -p "${meta_dir}"
    cat > "${meta_dir}/meta.conf" <<EOF
DEVTOOL_PACKAGE_KIND=${kind}
PKG_NAME=${PKG_NAME}
PKG_PATH=${pkg_path}
SOURCE_ORIGIN=${source_origin}
EOF
}

function FUNC_read_pkg_metadata(){
    local path=$1
    local meta_file="${path}/.devtool/meta.conf"

    DEVTOOL_PACKAGE_KIND=""
    SOURCE_ORIGIN=""
    if [[ -f "${meta_file}" ]]; then
        source "${meta_file}"
    fi
}
