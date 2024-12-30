#!/bin/bash


###
# GLOBAL VARIABLES DECLARATION
###

FLAG_OVERWRITE=0
MAJOR_VERSION="1"
MINOR_VERSION="3"
FIX_VERSION="1"
VERSION="${MAJOR_VERSION}.${MINOR_VERSION}.${FIX_VERSION}"

SHELL_PATH=""
SUB_COMMAND=""
MOD_PKG_LIST=""
NEW_PKG_LIST=""

CATEGORY=""
SUBMENU=""
TITLE=""
SAMPLE_PLUGIN_URL=""

FEED_NAME=""
FEED_MAKEFILE_URL=""

PKG_NAME=""
PKG_PATH=""
PKG_SOURCE_URL_ARC=""
PKG_SOURCE_URL_GIT=""
PKG_SOURCE_URL_GIT_BRANCH=""
PKG_SOURCE_URL_TYPE=""
PKG_TYPE=""

OPENWRT_DIR=""
OPENWRT_PKG_DIR=""

WORKSPACE_DIR_PARENT=""
WORKSPACE_DIR=""
WORKSPACE_FEED_DIR=""
WORKSPACE_FEED_PKG_DIR=""
WORKSPACE_PKG_DIR=""
WORKSPACE_PKG_ORI_DIR=""
WORKSPACE_SRC_DIR=""

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
    <WORKSPACE_DIR>/  <--- ${WORKSPACE_DIR_PARENT}
        devtool.sh             
        workspace/             
            FEEDS/
            PACKAGES/
            SOURCES/
    --------------------------------------------------
    "
    
    exit 1
}

function FUNC_housekeeping(){

    local empty_list=$( find ${WORKSPACE_DIR} -empty )

    if [[ -n ${empty_list} ]]; then

        echo "====================================================="
        echo "HOUSE KEEPING ( remove empty folders )"
        echo "====================================================="
        for p in ${empty_list}
        do
            echo "rm -r ${p}"
            rm -r ${p}
        done
    fi
}


function FUNC_is_folder_existed(){
    local dir=$1

    if [[ -d ${dir} ]]; then
        read -p "overwrite ${dir}?(y/n)"
        if [[ $REPLY == "y" ]]; then
            rm ${dir} -rf
            FLAG_OVERWRITE=1
        else
            exit 1
        fi
    fi
}

function FUNC_create_folder(){
    local dir=$1

    echo "Create folder \"${dir}\""
    mkdir -p ${dir}
}

function FUNC_get_new_pkg_list(){
    local new_pkg_list=""
    local new_pkg_workdir="${WORKSPACE_DIR}/FEEDS/feed_dev_pkg/"

    if [[ -d ${new_pkg_workdir} ]]; then
        new_pkg_list=$(find ${new_pkg_workdir} -mindepth 1 -type d)
    fi

    # export to global variable 
    NEW_PKG_LIST="${new_pkg_list}"
}


function FUNC_get_mod_pkg_list(){
    local mod_pkg_list=""
    local mod_pkg_workdir="${WORKSPACE_DIR}/PACKAGES/"

    if [[ -d ${mod_pkg_workdir}  ]]; then
        mod_pkg_makefile_list=$(find ${mod_pkg_workdir} -iname makefile -type f)
        mod_pkg_list=${mod_pkg_makefile_list//\/Makefile}
    fi

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
    git archive --remote="${SAMPLE_PLUGIN_URL}" main | tar -x

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
    
    local feed_expr="src-link ${FEED_NAME} ${WORKSPACE_FEED_DIR}"
    
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

    CATEGORY="pkg-dev"
    SUBMENU="pkg"
    TITLE="${PKG_NAME} short description here"
    DESCRIPTION="${PKG_NAME} long description here"

    SAMPLE_PLUGIN_URL="git@vcs-sw2.arcadyan.com.tw:prpl-dev/demo.git"
    FEED_MAKEFILE_URL="git@vcs-sw2.arcadyan.com.tw:prpl-dev/feed-template-makefile.git"

    FUNC_create_new_feed
    FUNC_create_new_source
    FUNC_register_local_feed
}

# ---------- MODIFY PACKAGE PROCESS (BEGIN) ----------

function FUNC_create_workspace_pkg_dir(){
    
    FUNC_is_folder_existed "${WORKSPACE_PKG_DIR}"
    FUNC_create_folder     "${WORKSPACE_PKG_DIR}"
    
    # copy openwrt pkg dir to workspace pkg dir
    if [[ -h ${OPENWRT_PKG_DIR} ]]; then
        # copy folder via symlink file
        cp -rL "${OPENWRT_PKG_DIR}" "${WORKSPACE_PKG_DIR}/.."
    else
        # copy folder
        cp -r "${OPENWRT_PKG_DIR}" "${WORKSPACE_PKG_DIR}/..}"
    fi
}

function FUNC_create_worksapce_pkg_ori_dir(){

    WORKSPACE_PKG_ORI_DIR="${WORKSPACE_PKG_DIR/PACKAGES/PACKAGES_ORIGIN}"
    FUNC_is_folder_existed "${WORKSPACE_PKG_ORI_DIR}"
    FUNC_create_folder     "${WORKSPACE_PKG_ORI_DIR}"

    # copy openwrt pkg dir to workspace pkg dir
    if [[ -h ${OPENWRT_PKG_DIR} ]]; then
        # copy symlink file
        rm -r "${WORKSPACE_PKG_ORI_DIR}"
        cp -rf "${OPENWRT_PKG_DIR}" "${WORKSPACE_PKG_ORI_DIR}"
    else
        # copy folder
        cp -r "${OPENWRT_PKG_DIR}" "${WORKSPACE_PKG_ORI_DIR}/.."
    fi
}

function FUNC_parse_url(){
    local url=$1
    local pkg_version=$( sed -E -n "s|.?PKG_SOURCE_VERSION.?=(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile )

    if [[ $url == *".git"* ]]; then
        PKG_SOURCE_URL_TYPE="git"
        PKG_SOURCE_URL_GIT=${url}
        PKG_SOURCE_URL_GIT_BRANCH=${pkg_version}
    elif [[ $url == *"archive"* ]]; then
        PKG_SOURCE_URL_TYPE="archive"
        PKG_SOURCE_URL_ARC="${url}"
        PKG_SOURCE_URL_GIT="${url/\/-\/archive\/*/.git}"
        PKG_SOURCE_URL_GIT_BRANCH="${url##*archive/}"
    fi
}

function FUNC_create_workspace_src_dir(){

    FUNC_is_folder_existed "${WORKSPACE_SRC_DIR}"
    FUNC_create_folder "${WORKSPACE_SRC_DIR}"
    local pkg_source_url=$( sed -E -n "s|.?PKG_SOURCE_URL.?=(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile )

    # Parse url 
    echo "FUNC_parse_url ${pkg_source_url}"
    FUNC_parse_url ${pkg_source_url}
    
    # Move to ${WORKSPACE_SRC_DIR}
    cd ${WORKSPACE_SRC_DIR}

    # Clone repository
    echo "git clone ${PKG_SOURCE_URL_GIT}"
    git clone ${PKG_SOURCE_URL_GIT} .

    # Create & Switch branch to dev
    echo "git checkout -b dev ${PKG_SOURCE_URL_GIT_BRANCH}"
    git checkout -b dev ${PKG_SOURCE_URL_GIT_BRANCH}
}

function FUNC_symlink_pkg_dir(){

    rm ${OPENWRT_PKG_DIR}
    ln -sf ${WORKSPACE_PKG_DIR} ${OPENWRT_PKG_DIR}

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

    # process
    FUNC_create_workspace_pkg_dir
    FUNC_create_worksapce_pkg_ori_dir
    FUNC_create_workspace_src_dir
    FUNC_symlink_pkg_dir
    FUNC_redirect_src_pkg_url

}

# ---------- LIST DEVELOPED PACKAGE PROCESS (BEGIN) ----------

function FUNC_run_list_dev_package_process(){
    
    SUB_COMMAND=$1

    local count=0
    local type=""
    local pkg_name=""
    local format="|%-03s|%-30s|%-10s|%-50s \n"
    local _format="|%-03d|%-30s|%-10s|%-50s \n"
    printf "${format}" "No." "PKG-NAME" "TYPE" "PKG-PATH"
    printf "${format}" "---" "--------" "----" "-------"

    for p in ${NEW_PKG_LIST}
    do
        type="new"
        pkg_name="${p##*/}"
        count=$(( count + 1 ))
        printf "${_format}" "${count}" "${p##*/}" "${type}" "${p/${WORKSPACE_DIR_PARENT}\/}"
    done

    for p in ${MOD_PKG_LIST}
    do
        type="modify"
        pkg_name="${p##*/}"
        count=$(( count + 1 ))
        printf "${_format}" "${count}" "${p##*/}" "${type}" "${p/${WORKSPACE_DIR_PARENT}\/}"
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

FUNC_abort_mod_pkg_work(){
    
    echo "do ${FUNCNAME[0]}"

    # remove openwrt pkg dir
    OPENWRT_PKG_DIR=$(find "${OPENWRT_DIR}/package" -name ${PKG_NAME})
    echo "rm -rf ${OPENWRT_PKG_DIR}"
    rm -rf ${OPENWRT_PKG_DIR}

    # restore origin openwrt pkg dir from workspace backup dir ( PACKAGE_ORIGIN/ )
    local symlink_path=""
    WORKSPACE_PKG_ORI_DIR=$(find "${WORKSPACE_DIR}/PACKAGES_ORIGIN" -name ${PKG_NAME})
    if [[ -h ${WORKSPACE_PKG_ORI_DIR} ]]; then
        symlink_path=$(readlink ${WORKSPACE_PKG_ORI_DIR})
        echo "ln -s ${symlink_path} ${OPENWRT_PKG_DIR}"
        ln -s ${symlink_path} ${OPENWRT_PKG_DIR}
    else
        echo "cp -r ${WORKSPACE_PKG_ORI_DIR} ${OPENWRT_PKG_DIR}"
        cp -r ${WORKSPACE_PKG_ORI_DIR} ${OPENWRT_PKG_DIR}
    fi

    # remove workspace pkg ori dir
    echo "rm -rf ${WORKSPACE_PKG_ORI_DIR}"
    rm -rf ${WORKSPACE_PKG_ORI_DIR}

    # remove worksapce pkg dir
    WORKSPACE_PKG_DIR=$(find "${WORKSPACE_DIR}/PACKAGES" -name ${PKG_NAME})
    echo "rm -rf ${WORKSPACE_PKG_DIR}"
    rm -rf ${WORKSPACE_PKG_DIR}

    # remove worksapce src dir
    WORKSPACE_SRC_DIR=$(find "${WORKSPACE_DIR}/SOURCES" -name ${PKG_NAME})
    echo "rm -rf ${WORKSPACE_SRC_DIR}"
    rm -rf ${WORKSPACE_SRC_DIR}
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
WORKSPACE_DIR_PARENT="${SHELL_PATH%/*}"
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
        #FUNC_housekeeping
        ;;
    *)
        HELP
        exit 1
        ;;
esac

