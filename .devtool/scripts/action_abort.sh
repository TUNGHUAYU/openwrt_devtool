
function FUNC_abort_new_pkg_work(){
    echo "do ${FUNCNAME[0]}"

    local path=""

    # 1. remove "<openwrt>/build_dir/../<pkg>/"
    path=$(find ${OPENWRT_DIR}/build_dir/target-*/ -maxdepth 1 -name "${PKG_NAME}*" -type d)
    echo "rm -rf $path"
    rm -rf $path

    # 2. uninstall "<openwrt>/package/.../<pkg>"
    path=$(find ${OPENWRT_DIR}/package/ -name "${PKG_NAME}")
    echo "cd ${OPENWRT_DIR}"
    cd ${OPENWRT_DIR}
    echo "./scripts/feeds uninstall ${PKG_NAME}"
    ./scripts/feeds uninstall ${PKG_NAME}

    # 3. remove "<workspace>/SOURCES/<pkg>/"
    path=$(find ${DEVTOOL_WORKSPACE_SRC_DIR} -maxdepth 1 -name "${PKG_NAME}" -type d)
    echo "rm -rf $path"
    rm -rf  $path

    # 4. remove "<workspace>/FEEDS/feed_dev_pkg/<pkg>"
    path=$(find ${DEVTOOL_WORKSPACE_FEED_DIR} -name "${PKG_NAME}" -type d)
    echo "rm -rf $path"
    rm -rf $path
}

FUNC_abort_mod_pkg_work(){
    
    echo "do ${FUNCNAME[0]}"
    local path=""

    # 1. remove openwrt pkg dir
    OPENWRT_PKG_DIR=$(find "${OPENWRT_DIR}/package" -name ${PKG_NAME})
    echo "rm -rf ${OPENWRT_PKG_DIR}"
    rm -rf ${OPENWRT_PKG_DIR}

    # 2. restore origin openwrt pkg dir from workspace backup dir ( PACKAGE_ORIGIN/ )
    local symlink_path=""
    path=$(find "${DEVTOOL_WORKSPACE_ORIPKG_DIR}" -name ${PKG_NAME})
    if [[ -h ${path} ]]; then
        symlink_path=$(readlink ${path})
        echo "ln -s ${symlink_path} ${OPENWRT_PKG_DIR}"
        ln -s ${symlink_path} ${OPENWRT_PKG_DIR}
    else
        echo "cp -r ${path} ${OPENWRT_PKG_DIR}"
        cp -r ${path} ${OPENWRT_PKG_DIR}
    fi

    [[ -e ${path} ]] && echo "rm -rf ${path}" # remove workspace pkg ori dir
    [[ -e ${path} ]] && rm -rf ${path}

    # 3. remove worksapce pkg dir
    path=$(find "${DEVTOOL_WORKSPACE_PKG_DIR}" -name ${PKG_NAME})
    [[ -e ${path} ]] && echo "rm -rf ${path}"
    [[ -e ${path} ]] && rm -rf ${path}

    # 4. remove worksapce src dir
    path=$(find "${DEVTOOL_WORKSPACE_SRC_DIR}" -name ${PKG_NAME})
    [[ -e ${path} ]] && echo "rm -rf ${path}"
    [[ -e ${path} ]] && rm -rf ${path}

    # 5. remove temporary config (<openwrt>/tmp/)
    path=$(find "${OPENWRT_DIR}/tmp/info" -name ".packageinfo-*${PKG_NAME}")
    [[ -f ${path} ]] && echo "rm ${path}"
    [[ -f ${path} ]] && rm ${path}
}

function FUNC_action_abort(){

    # tui: package selection
    local list="${NEW_PKG_LIST} ${MOD_PKG_LIST}"
    FUNC_tui_select \
    "${list}" \
    "${DEVTOOL_DIR}/" \
    "Please select package to abort:"

    PKG_NAME=${RESULT##*/}

    # double check remove the specific package
    read -e -p "Please enter the whole name of the package that you want to DELET:"
    if [[ ${REPLY} != "${PKG_NAME}" ]]; then
        devtool_print ${LOG_ERRO} "Wrong package name!!"
        exit ${ERROR_WRONG_ABORT_PKG_NAME}
    fi

    # # Determin PKG_TYPE
    FUNC_check_pkg_devloping
    echo "PKG_TYPE:${PKG_TYPE}"
    echo 

    # Check if package name has been developed
    case "${PKG_TYPE}" in
        new )
            # abort new type package
            FUNC_abort_new_pkg_work
            ;;
        modify )
            # abort modify type package
            FUNC_abort_mod_pkg_work
            ;;
        * )
            echo "WARN: package has NOT been developed!!"
            exit 2
            ;;
    esac

}
