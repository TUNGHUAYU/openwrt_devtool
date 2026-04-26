
function FUNC_create_workspace_pkg_dir(){
    
    local path="${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"

    FUNC_is_folder_existed "${path}"
    FUNC_create_folder     "${path}"
    
    # copy openwrt pkg dir to workspace pkg dir
    if [[ -h ${OPENWRT_PKG_DIR} ]]; then
        # copy folder via symlink file
        cp -rL "${OPENWRT_PKG_DIR}" "${path}/.."
    else
        # copy folder
        cp -r "${OPENWRT_PKG_DIR}" "${path}/.."
    fi
}

function FUNC_create_worksapce_pkg_ori_dir(){

    local path="${DEVTOOL_WORKSPACE_ORIPKG_DIR}/${PKG_PATH}"
    
    FUNC_is_folder_existed "${path}"
    FUNC_create_folder     "${path}"

    # copy openwrt pkg dir to workspace pkg dir
    if [[ -h ${OPENWRT_PKG_DIR} ]]; then
        # copy symlink file
        rm -r "${path}"
        cp -rf "${OPENWRT_PKG_DIR}" "${path}"
    else
        # copy folder
        cp -r "${OPENWRT_PKG_DIR}" "${path}/.."
    fi
}

function FUNC_parse_url(){
    local url=$1
    local pkg_source_version=$( sed -E -n "s|^[[:space:]]*PKG_SOURCE_VERSION[[:space:]]*:?=[[:space:]]*(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile | head -n 1 )
    local pkg_version=$( sed -E -n "s|^[[:space:]]*PKG_VERSION[[:space:]]*:?=[[:space:]]*(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile | head -n 1 )

    PKG_SOURCE_URL_TYPE=""
    PKG_SOURCE_URL_GIT=""
    PKG_SOURCE_URL_GIT_BRANCH=""
    PKG_SOURCE_URL_ARC=""
    PKG_SOURCE_URL_TARBALL=""

    # workaround: PKG_SOURCE_VERSION:=v$(PKG_VERSION) in Makefile
    if [[ ${pkg_source_version} =~ \$\(PKG_VERSION\) ]]; then
        pkg_source_version=v${pkg_version}
    fi
    [[ -z ${pkg_source_version} ]] && pkg_source_version=${pkg_version}

    # url ONLY support 2 types shows below:
    # (1) remote git repository url: git@<server_hostname>:<server_path>.git
    # (2) gitlab archive url: https://gitlab.com/xxxx-/archive/<branch>
    if [[ $url == git@* ]] || [[ $url == *".git"* ]]; then
        PKG_SOURCE_URL_TYPE="git"
        PKG_SOURCE_URL_GIT=${url}
        PKG_SOURCE_URL_GIT_BRANCH=${pkg_source_version}
    elif [[ $url == *"archive"* ]]; then
        PKG_SOURCE_URL_TYPE="archive"
        PKG_SOURCE_URL_ARC="${url}"
        PKG_SOURCE_URL_GIT="${url/\/-\/archive\/*/.git}"
        PKG_SOURCE_URL_GIT_BRANCH="${url##*archive/}"
    else
        PKG_SOURCE_URL_TYPE="tarball"
        PKG_SOURCE_URL_TARBALL="${url}"
        PKG_SOURCE_URL_GIT_BRANCH=${pkg_source_version}
    fi
}

function FUNC_find_prepared_src_dir(){
    local build_dir="${OPENWRT_DIR}/build_dir"
    local prepared_dir=""

    prepared_dir=$(find "${build_dir}" -path "*/target-*" -type d -name "${PKG_NAME}*${PKG_SOURCE_URL_GIT_BRANCH}*" 2>/dev/null | sort | tail -n 1)
    if [[ -z ${prepared_dir} ]]; then
        prepared_dir=$(find "${build_dir}" -path "*/target-*" -type d -name "${PKG_NAME}*" 2>/dev/null | sort | tail -n 1)
    fi

    RESULT=${prepared_dir}
}

function FUNC_init_workspace_src_git(){
    local path=$1

    git -C "${path}" init
    git -C "${path}" add .
    git -C "${path}" commit -m "ref-base source"
    git -C "${path}" branch ref-base
    git -C "${path}" checkout -b dev ref-base
}

function FUNC_create_workspace_src_dir_git(){
    local path=$1

    # Clone repository
    echo "git clone ${PKG_SOURCE_URL_GIT} ."
    git clone ${PKG_SOURCE_URL_GIT} . || return $?

    # Create base and development branches
    echo "git checkout -b ref-base ${PKG_SOURCE_URL_GIT_BRANCH}"
    git checkout -b ref-base ${PKG_SOURCE_URL_GIT_BRANCH} || return $?
    echo "git checkout -b dev ref-base"
    git checkout -b dev ref-base || return $?
}

function FUNC_create_workspace_src_dir_tarball(){
    local path=$1
    local prepared_dir=""

    echo "make -C ${OPENWRT_DIR} package/${PKG_PATH}/prepare V=s"
    make -C "${OPENWRT_DIR}" "package/${PKG_PATH}/prepare" V=s || return $?

    FUNC_find_prepared_src_dir
    prepared_dir=${RESULT}
    if [[ -z ${prepared_dir} ]] || [[ ! -d ${prepared_dir} ]]; then
        echo "ERROR: prepared source directory not found for ${PKG_NAME}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    echo "cp -r ${prepared_dir}/. ${path}/"
    cp -r "${prepared_dir}/." "${path}/" || return $?
    FUNC_init_workspace_src_git "${path}" || return $?
}

function FUNC_create_workspace_src_dir(){

    local path="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"

    FUNC_is_folder_existed "${path}"
    FUNC_create_folder "${path}"
    local pkg_source_url=$( sed -E -n "s|^[[:space:]]*PKG_SOURCE_URL[[:space:]]*:?=[[:space:]]*(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile | head -n 1 )

    # Parse url 
    echo "FUNC_parse_url ${pkg_source_url}"
    FUNC_parse_url ${pkg_source_url}
    
    # Move to source director
    cd ${path}

    case "${PKG_SOURCE_URL_TYPE}" in
        git|archive)
            FUNC_create_workspace_src_dir_git "${path}"
            ;;
        tarball)
            FUNC_create_workspace_src_dir_tarball "${path}"
            ;;
        *)
            echo "ERROR: unsupported PKG_SOURCE_URL=${pkg_source_url}"
            return ${ERROR_NOT_GIT_REPO}
            ;;
    esac
}

function FUNC_symlink_pkg_dir(){

    rm ${OPENWRT_PKG_DIR}
    ln -sf "${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}" ${OPENWRT_PKG_DIR}

}

function FUNC_redirect_src_pkg_url(){

    local path="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"


    cd "${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"

    # comment all variable with leading "PKG_"
    sed -i "/^PKG_.*=/ s/^/# /"                             Makefile

    # insert redirection necessary variables
    sed -i "1i \\
    ###########################################\\
    # insert by openwrt-devtool automatically \\
    PKG_SOURCE_URL:=file://${path}\\
    PKG_SOURCE_PROTO:=git\\
    PKG_SOURCE_VERSION:=ref-base\\
    PKG_NAME:=${PKG_NAME}\\
    PKG_VERSION:=${PKG_SOURCE_URL_GIT_BRANCH}\\
    PKG_RELEASE:=1\\
    ###########################################" Makefile 

}

function FUNC_modify_dry_run_plan(){

    local pkg_source_url=$( sed -E -n "s|.?PKG_SOURCE_URL.?=(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile )
    FUNC_parse_url ${pkg_source_url}

    echo "DRY-RUN modify package: ${PKG_NAME}"
    echo "source package: ${OPENWRT_PKG_DIR}"
    echo "workspace package: ${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"
    echo "workspace original backup: ${DEVTOOL_WORKSPACE_ORIPKG_DIR}/${PKG_PATH}"
    echo "workspace source: ${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    if [[ "${PKG_SOURCE_URL_TYPE}" == "tarball" ]]; then
        echo "prepare tarball source with OpenWrt: make -C ${OPENWRT_DIR} package/${PKG_PATH}/prepare V=s"
    else
        echo "clone source repository: ${PKG_SOURCE_URL_GIT}"
    fi
    echo "create ref-base branch at ${PKG_SOURCE_URL_GIT_BRANCH}"
    echo "checkout dev branch from ref-base"
    echo "replace OpenWrt package with symlink to workspace package"
    echo "rewrite Makefile with PKG_SOURCE_URL:=file://${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    echo "rewrite Makefile with PKG_SOURCE_VERSION:=ref-base"
}

function FUNC_action_modify(){

    PKG_NAME_PATTERN=${1:-}
    MODIFY_DRY_RUN=${2:-}
    
    # tui: package selection
    local list="$( find -L ${OPENWRT_DIR}/package/feeds/ -iname makefile | grep "${PKG_NAME_PATTERN}" | sed 's|/Makefile$||' )"
    FUNC_tui_select \
    "${list}" \
    "${OPENWRT_DIR}/package/feeds/" \
    "Please select package to modify:" \
    "" \
    "" \
    ""

    OPENWRT_PKG_DIR=${RESULT}
    echo "OPENWRT_PKG_DIR: ${OPENWRT_PKG_DIR}"
    read 

    # Define variables
    PKG_NAME=${OPENWRT_PKG_DIR##*/}
    PKG_PATH=${OPENWRT_PKG_DIR##*package/}
    DEVTOOL_PKG_DIR="${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"

    # Determin PKG_TYPE
    FUNC_check_pkg_type

    # Check if the package hasn't been developed
    case "${PKG_TYPE}" in
        none )
            if [[ "${MODIFY_DRY_RUN}" == "--dry-run" ]]; then
                FUNC_modify_dry_run_plan
                return
            fi

            # process
            FUNC_create_workspace_src_dir || return $?
            FUNC_create_workspace_pkg_dir
            FUNC_create_worksapce_pkg_ori_dir
            FUNC_symlink_pkg_dir
            FUNC_redirect_src_pkg_url    
            ;;
            
        * )
            echo "ERROR: package has been developed!!"
            exit 2
            ;;
    esac
}
