#!/bin/bash
FLAG_OVERWRITE=0
MAJOR_VERSION="1"
MINOR_VERSION="2"
FIX_VERSION="2"
VERSION="${MAJOR_VERSION}.${MINOR_VERSION}.${FIX_VERSION}"

###
# FUNCTION
###


function HELP(){

    local shell_name=${0##*/}

    echo "version:v${VERSION}"
    echo " 
    --------------------------------------------------
    Usage
    --------------------------------------------------
    $0 list
    $0 new    <OPENWRT_DIR> <PKG_NAME>
    $0 modify <OPENWRT_PKG_DIR>
    $0 abort  <OPENWRT_DIR> <PKG_NAME>
    --------------------------------------------------
    OpenWRT Layout
    --------------------------------------------------
    openwrt/                 <--- <OPENWRT_DIR>
        feeds.conf
        feeds/
        package/
            .../
                <pkg>/       <--- <OPENWRT_PKG_DIR>
                    Makefile
        build_dir/
    --------------------------------------------------
    WORKSPACE Layout
    --------------------------------------------------
    <WORKSPACE_DIR>/  <--- ${ROOT_WORKSPACE_DIR}
        devtool.sh             
        workspace/             
            FEEDS/
            PACKAGES/
            SOURCES/
    --------------------------------------------------
    "
    
    exit 1
}

function FUNC_is_folder_existed(){
    local DIR=$1

    if [[ -d ${DIR} ]]; then
        read -p "overwrite ${DIR}?(y/n)"
        if [[ $REPLY == "y" ]]; then
            rm ${DIR} -rf
            FLAG_OVERWRITE=1
        else
            exit 1
        fi
    fi
}

function FUNC_create_folder(){
    local DIR=$1

    echo "Create folder \"${DIR}\""
    mkdir -p ${DIR}
}

function FUNC_get_new_pkg_list(){
    local new_pkg_list=""
    new_pkg_list=$(find ${WORKSPACE_DIR}/FEEDS/feed_dev_pkg/ -mindepth 1 -type d)

    # export to global variable 
    NEW_PKG_LIST="${new_pkg_list}"
}


function FUNC_get_mod_pkg_list(){
    local mod_pkg_list=""
    mod_pkg_makefile_list=$(find ${WORKSPACE_DIR}/PACKAGES/ -iname makefile -type f)
    mod_pkg_list=${mod_pkg_makefile_list//\/Makefile}

    # export to global variable
    MOD_PKG_LIST="${mod_pkg_list}"
}


# ---------- NEW PACKAGE PROCESS (BEGIN) ----------

function FUNC_create_new_feed(){
    FUNC_is_folder_existed "${WORKSPACE_FEED_PKG_DIR}"
    FUNC_create_folder "${WORKSPACE_FEED_PKG_DIR}"

    cd "${WORKSPACE_FEED_PKG_DIR}"
    git archive --remote="${FEED_MAKEFILE_URL}" main | tar -x
    sed -n "s#<pkg-name>#${PKG_NAME}#p"                                Makefile
    sed -n "s#<repo-branch>#dev#p"                                     Makefile
    sed -n "s#<local-repo-url>#${WORKSPACE_SRC_DIR}#p"                 Makefile
    sed -n "s#<category>#${CATEGORY}#p"                                Makefile
    sed -n "s#<submenu>#${SUBMENU}#p"                                  Makefile
    sed -n "s#<title>#${TITLE}#p"                                      Makefile
    sed -n "s#<description>#${DESCRIPTION}#p"                          Makefile
    
    sed -i "s#<pkg-name>#${PKG_NAME}#g"                                Makefile
    sed -i "s#<repo-branch>#dev#g"                                     Makefile
    sed -i "s#<local-repo-url>#${WORKSPACE_SRC_DIR}#g"                 Makefile
    sed -i "s#<category>#${CATEGORY}#g"                                Makefile
    sed -i "s#<submenu>#${SUBMENU}#g"                                  Makefile
    sed -i "s#<title>#${TITLE}#g"                                      Makefile
    sed -i "s#<description>#${DESCRIPTION}#g"                          Makefile

    cd - > /dev/null
}

function FUNC_create_new_source(){
    FUNC_is_folder_existed "${WORKSPACE_SRC_DIR}"
    FUNC_create_folder "${WORKSPACE_SRC_DIR}"

    cd "${WORKSPACE_SRC_DIR}"
    git archive --remote="${REMOTE_URL}" main | tar -x

    # convert content "demo" to "${PKG_NAME}"
    {
    echo "## Replace content with \"${PKG_NAME}\""
    
    # convert content with ${PKG_NAME}
    grep -rni --color=never "demo"  | \
    awk -F":" \
    -v PKG_NAME=${PKG_NAME} \
    '
    /demo/{
        printf "# %s\n", $0 
        printf "sed -i \x27%ss/%s/%s/g\x27 %s\n", $2, "demo", PKG_NAME, $1
        printf "\n"
    }
    
    /DEMO/{
        printf "# %s\n", $0 
        printf "sed -i \x27%ss/%s/%s/g\x27 %s\n", $2, "DEMO", toupper(PKG_NAME), $1
        printf "\n"
    }
    
    /Demo/{
        printf "# %s\n", $0 
        printf "sed -i \x27%ss/%s/%s/g\x27 %s\n", $2, "Demo", PKG_NAME, $1
        printf "\n"
    }
    ' 
    } >> .convert.cmd

    # convert filename to ${PKG_NAME}
    {
    echo "## Replace filename with pattern, \"${PKG_NAME}\""
    
    for p in $(find . -name "*demo*")
    do
        rename_p=$( echo $p | sed s/demo/${PKG_NAME}/g )
        echo "mv $p $rename_p" 
        echo ""                
    done
    } >> .convert.cmd

    # execute convert action
    #echo "Execute .convert.cmd that conver filename and content for \"${PKG_NAME}\""
    bash .convert.cmd
        
    # initial git
    git init
    git add . 
    git commit -m "first commit"
    git checkout -b dev
    
    cd - > /dev/null
}

function FUNC_register_local_feed(){
    # openwrt 
    cd ${OPENWRT_DIR}
    
    feed_expr="src-link ${FEED_NAME} ${WORKSPACE_FEED_DIR}"
    
    ret=$(grep "src-link ${FEED_NAME}" feeds.conf)
    if [[ -z $ret ]]; then
        echo "${feed_expr} >> feeds.conf"
        echo ${feed_expr} >> feeds.conf
    else
        echo "Activate feed -> \"src-link ${FEED_NAME}\""
        sed -i "/src-link ${FEED_NAME}/ c\\${feed_expr}" feeds.conf
    fi

    ./scripts/feeds update ${FEED_NAME}
    ./scripts/feeds install -p ${FEED_NAME} ${PKG_NAME}
    
    cd - > /dev/null
}

function FUNC_run_new_package_process(){

    SUB_COMMAND=$1
    OPENWRT_DIR=$2
    PKG_NAME=$3
    
    FEED_NAME="feed_dev_pkg"

    WORKSPACE_SRC_DIR="${WORKSPACE_DIR}/SOURCES/${PKG_NAME}"
    WORKSPACE_FEED_DIR="${WORKSPACE_DIR}/FEEDS/${FEED_NAME}"
    WORKSPACE_FEED_PKG_DIR="${WORKSPACE_DIR}/FEEDS/${FEED_NAME}/${PKG_NAME}"

    REPO_BRANCH="main"
    CATEGORY="pkg-dev"
    SUBMENU="pkg"
    TITLE="${PKG_NAME}"

    REMOTE_URL="git@vcs-sw2.arcadyan.com.tw:prpl-dev/demo.git"
    FEED_MAKEFILE_URL="git@vcs-sw2.arcadyan.com.tw:prpl-dev/feed-template-makefile.git"

    FUNC_create_new_feed
    FUNC_create_new_source
    FUNC_register_local_feed
}

# ---------- MODIFY PACKAGE PROCESS (BEGIN) ----------

function FUNC_symlink_modify_makefile(){
    FUNC_is_folder_existed "${WORKSPACE_PKG_DIR}"
    FUNC_create_folder     "${WORKSPACE_PKG_DIR}"

    # Move to ${WORKSPACE_PKG_DIR}
    cd ${WORKSPACE_PKG_DIR}

    # Backup/Restore package original Makefile
    if [[ ! -e ${OPENWRT_PKG_DIR}/.Makefile.origin ]]; then
        cp ${OPENWRT_PKG_DIR}/Makefile ${OPENWRT_PKG_DIR}/.Makefile.origin
    fi

    # Create symlink
    rm ${OPENWRT_PKG_DIR}/Makefile
    cp ${OPENWRT_PKG_DIR}/.Makefile.origin ${WORKSPACE_PKG_DIR}/Makefile
    ln -sf ${WORKSPACE_PKG_DIR}/Makefile ${OPENWRT_PKG_DIR}/Makefile
}

function FUNC_convert_git_url(){
    local url=$1

    if [[ $url == *".git"* ]]; then
        PKG_SOURCE_URL_GIT=${url}
    elif [[ $url == *"archive"* ]]; then
        PKG_SOURCE_URL_ARC=${url}
        PKG_SOURCE_URL_GIT=${url/\/-\/archive\/*/.git}
    fi

}

function FUNC_create_modify_source(){
    FUNC_is_folder_existed "${WORKSPACE_SRC_DIR}"
    FUNC_create_folder "${WORKSPACE_SRC_DIR}"
   
    cd ${WORKSPACE_SRC_DIR}

    local pkg_source_url=$( sed -E -n "s#.?PKG_SOURCE_URL.?=(.*)#\1#p" ${OPENWRT_PKG_DIR}/Makefile )
    local pkg_version=$(    sed -E -n "s#.?PKG_SOURCE_VERSION.?=(.*)#\1#p" ${OPENWRT_PKG_DIR}/Makefile    )

    echo "pkg_source_url=${pkg_source_url}"
    FUNC_convert_git_url ${pkg_source_url}

    echo "git clone ${PKG_SOURCE_URL_GIT}"
    git clone ${PKG_SOURCE_URL_GIT} .
    echo "git checkout -b dev ${pkg_version}"
    git checkout -b dev ${pkg_version}
}

function FUNC_redirect_src_pkg_url(){

    cd ${WORKSPACE_PKG_DIR}

    sed -i "/^PKG_SOURCE_URL/ s/^/# /"                                  Makefile
    sed -i "/^PKG_SOURCE_PROTO/ s/^/# /"                                Makefile
    sed -i "/^PKG_SOURCE_VERSION/ s/^/# /"                              Makefile

    sed -i "/^PKG_SOURCE:=/ s/^/# /"                                    Makefile
    sed -i "/^PKG_HASH:=/ s/^/# /"                                      Makefile
    sed -i "/^PKG_BUILD_DIR:=/ s/^/# /"                                 Makefile
    sed -i "/^PKG_LICENSE:=/ s/^/# /"                                   Makefile
    sed -i "/^PKG_LICENSE_FILES:=/ s/^/# /"                             Makefile
    sed -i "/^PKG_RELEASE:=/ s/^/# /"                                   Makefile

    sed -i "/^# PKG_SOURCE_URL/ a PKG_SOURCE_URL:=file://${WORKSPACE_SRC_DIR}" Makefile
    sed -i "/PKG_SOURCE_URL:=file/ a PKG_SOURCE_PROTO:=git"                    Makefile
    sed -i "/PKG_SOURCE_URL:=file/ a PKG_SOURCE_VERSION:=dev"                  Makefile
}

function FUNC_run_modify_package_process(){

    SUB_COMMAND=$1
    OPENWRT_PKG_DIR=$2

    PKG_NAME=${OPENWRT_PKG_DIR##*/}
    PKG_PATH=${OPENWRT_PKG_DIR##*package/}
    WORKSPACE_PKG_DIR="${WORKSPACE_DIR}/PACKAGES/${PKG_PATH}"
    WORKSPACE_SRC_DIR="${WORKSPACE_DIR}/SOURCES/${PKG_NAME}"

    FUNC_symlink_modify_makefile
    FUNC_create_modify_source
    FUNC_redirect_src_pkg_url
}

# ---------- LIST DEVELOPED PACKAGE PROCESS (BEGIN) ----------

function FUNC_run_list_dev_package_process(){
    
    SUB_COMMAND=$1

    local count=0
    local type=""
    local format="|%-03s|%-30s|%-10s|%-50s \n"
    local _format="|%-03d|%-30s|%-10s|%-50s \n"
    printf "${format}" "No." "PKG-NAME" "TYPE" "PKG-PATH"
    printf "${format}" "---" "--------" "----" "-------"

    for p in ${NEW_PKG_LIST}
    do
        type="new"
        count=$(( count + 1 ))
        printf "${_format}" "${count}" "${p##*/}" "${type}" "${p}"
    done

    for p in ${MOD_PKG_LIST}
    do
        type="modify"
        count=$(( count + 1 ))
        printf "${_format}" "${count}" "${p##*/}" "${type}" "${p}"
    done


}


# ---------- ABORT DEVELOPED PACKAGE PROCESS (BEGIN) ----------

function FUNC_check_pkg_devloping(){
    local pkg_name=""
    echo $pkg_name

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
}



function FUNC_abort_new_pkg_work(){
    echo "do ${FUNCNAME[0]}"
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
    path=$(find ${WORKSPACE_DIR}/SOURCES/ -maxdepth 1 -name "${PKG_NAME}" -type d)
    echo "rm -rf $path"
    rm -rf  $path
    # 4. remove "<workspace>/FEEDS/feed_dev_pkg/<pkg>"
    path=$(find ${WORKSPACE_DIR}/FEEDS/ -name "${PKG_NAME}" -type d)
    echo "rm -rf $path"
    rm -rf $path
}

function FUNC_abort_mod_pkg_work(){
    echo "do ${FUNCNAME[0]}"

    local path=""

    # 1. remove "<openwrt>/build_dir/../<pkg>/"
    path=$(find ${OPENWRT_DIR}/build_dir/target-*/ -maxdepth 1 -name "${PKG_NAME}*" -type d)
    echo "rm -rf $path"
    rm -rf $path
    # 2. restore package openwrt-Makefile via ".Makefile.origin"
    path=$(find ${OPENWRT_DIR}/package/ -name "${PKG_NAME}")
    echo "rm $path/Makefile"
    echo "cp $path/.Makefile.origin $path/Makefile"
    echo "rm $path/.Makefile.origin"
    rm $path/Makefile
    cp $path/.Makefile.origin $path/Makefile
    rm $path/.Makefile.origin
    # 3. remove "<workspace>/SOURCES/<pkg>"
    path=$(find ${WORKSPACE_DIR}/SOURCES/ -maxdepth 1 -name "${PKG_NAME}" -type d)
    echo "rm -rf $path"
    rm -rf $path
    # 4. remove "<workspace>/PACKAGES/.../<pkg>"
    path=$(find ${WORKSPACE_DIR}/PACKAGES/ -name "${PKG_NAME}" -type d)
    echo "rm -rf $path"
    rm -rf $path
}

function FUNC_run_abort_dev_package_process(){

    SUB_COMMAND=$1
    OPENWRT_DIR=$2
    PKG_NAME=$3

    # Check if package name is legal
    FUNC_check_pkg_devloping

    # 
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
            echo "abort ... ${FUNCNAME[0]}"
            exit 2
            ;;
    esac

}

###
# MAIN
###

PKG_TYPE="none"
SHELL_PATH=$(realpath $0)
ROOT_WORKSPACE_DIR="${SHELL_PATH%/*}"
WORKSPACE_DIR="${SHELL_PATH%/*}/workspace"
SUB_COMMAND=$1

FUNC_get_new_pkg_list
FUNC_get_mod_pkg_list

case "${SUB_COMMAND}" in
    new )
        echo "new package"
        if [[ $# != 3 ]]; then
            HELP
            exit 1
        fi
        OPENWRT_DIR=$(realpath $2)
        PKG_NAME=$3
        FUNC_run_new_package_process ${SUB_COMMAND} ${OPENWRT_DIR} ${PKG_NAME}
        ;;
    modify )
        echo "modify package"
        if [[ $# != 2 ]]; then
            HELP
            exit 1
        fi
        OPENWRT_PKG_DIR=$(realpath -s $2)
        FUNC_run_modify_package_process ${SUB_COMMAND} ${OPENWRT_PKG_DIR}
        ;;
    list )
        echo "list developed packages"
        if [[ $# != 1 ]]; then
            HELP
            exit 1
        fi
        FUNC_run_list_dev_package_process ${SUB_COMMAND}
        ;;
    abort )
        echo "abort developed package"
        if [[ $# != 3 ]]; then
            HELP
            exit 1
        fi
        OPENWRT_DIR=$(realpath $2)
        PKG_NAME=$3
        FUNC_run_abort_dev_package_process ${SUB_COMMAND} ${OPENWRT_DIR} ${PKG_NAME}
        ;;
    *)
        HELP
        exit 1
        ;;
esac
