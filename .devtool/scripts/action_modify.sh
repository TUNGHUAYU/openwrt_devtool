
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
        cp -r "${OPENWRT_PKG_DIR}" "${path}/..}"
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
    local pkg_source_version=$( sed -E -n "s|.?PKG_SOURCE_VERSION.?=(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile )
    local pkg_version=$( sed -E -n "s|.?PKG_VERSION.?=(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile )

    # workaround: PKG_SOURCE_VERSION:=v$(PKG_VERSION) in Makefile
    if [[ ${pkg_source_version} =~ \$\(PKG_VERSION\) ]]; then
        pkg_source_version=v${pkg_version}
    fi

    # url ONLY support 2 types shows below:
    # (1) remote git repository url: git@<server_hostname>:<server_path>.git
    # (2) gitlab archive url: https://gitlab.com/xxxx-/archive/<branch>
    if [[ $url == *".git"* ]]; then
        PKG_SOURCE_URL_TYPE="git"
        PKG_SOURCE_URL_GIT=${url}
        PKG_SOURCE_URL_GIT_BRANCH=${pkg_source_version}
    elif [[ $url == *"archive"* ]]; then
        PKG_SOURCE_URL_TYPE="archive"
        PKG_SOURCE_URL_ARC="${url}"
        PKG_SOURCE_URL_GIT="${url/\/-\/archive\/*/.git}"
        PKG_SOURCE_URL_GIT_BRANCH="${url##*archive/}"
    fi
}

function FUNC_create_workspace_src_dir(){

    local path="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"

    FUNC_is_folder_existed "${path}"
    FUNC_create_folder "${path}"
    local pkg_source_url=$( sed -E -n "s|.?PKG_SOURCE_URL.?=(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile )

    # Parse url 
    echo "FUNC_parse_url ${pkg_source_url}"
    FUNC_parse_url ${pkg_source_url}
    
    # Move to source director
    cd ${path}

    # Clone repository
    echo "git clone ${PKG_SOURCE_URL_GIT} ."
    git clone ${PKG_SOURCE_URL_GIT} .

    # Create & Switch branch to dev
    echo "git checkout -b dev ${PKG_SOURCE_URL_GIT_BRANCH}"
    git checkout -b dev ${PKG_SOURCE_URL_GIT_BRANCH}
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
    PKG_SOURCE_VERSION:=dev\\
    PKG_NAME:=${PKG_NAME}\\
    PKG_VERSION:=${PKG_SOURCE_URL_GIT_BRANCH}\\
    PKG_RELEASE:=1\\
    ###########################################" Makefile 

}

function FUNC_action_modify(){

    PKG_NAME_PATTERN=$1
    
    # tui: package selection
    local list="$( find -L ${OPENWRT_DIR}/package/feeds/ -iname makefile | grep ${PKG_NAME_PATTERN} | sed 's|/Makefile$||' )"
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
    FUNC_check_pkg_devloping

    # Check if the package hasn't been developed
    case "${PKG_TYPE}" in
        none )
            # process
            FUNC_create_workspace_pkg_dir
            FUNC_create_worksapce_pkg_ori_dir
            FUNC_create_workspace_src_dir
            FUNC_symlink_pkg_dir
            FUNC_redirect_src_pkg_url    
            ;;
            
        * )
            echo "ERROR: package has been developed!!"
            exit 2
            ;;
    esac
}