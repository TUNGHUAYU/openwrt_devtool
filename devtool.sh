#!/bin/bash

FLAG_OVERWRITE=0
VERSION="v1.0.0"

###
# FUNCTION
###


function HELP(){
    echo "version:${VERSION}"
    echo ""
    echo "$0 new <OPENWRT_DIR> <PKG_NAME>"
    echo "    => New prpl sample plugin package"
    echo ""
    echo "$0 modify <OPENWRT_PKG_DIR>"
    echo "    => Modify existed package"
    echo ""
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

function FUNC_create_new_feed(){
    FUNC_is_folder_existed "${PKG_FEED_DIR}"
    FUNC_create_folder "${PKG_FEED_DIR}"

    cd "${PKG_FEED_DIR}"
    git archive --remote="${FEED_MAKEFILE_URL}" main | tar -x
    sed -n "s#<pkg-name>#${PKG_NAME}#p"                                Makefile
    sed -n "s#<repo-branch>#${REPO_BRANCH}#p"                          Makefile
    sed -n "s#<local-repo-url>#${PKG_SRC_DIR}#p"                       Makefile
    sed -n "s#<category>#${CATEGORY}#p"                                Makefile
    sed -n "s#<submenu>#${SUBMENU}#p"                                  Makefile
    sed -n "s#<title>#${TITLE}#p"                                      Makefile
    sed -n "s#<description>#${DESCRIPTION}#p"                          Makefile
    
    sed -i "s#<pkg-name>#${PKG_NAME}#g"                                Makefile
    sed -i "s#<repo-branch>#${REPO_BRANCH}#g"                          Makefile
    sed -i "s#<local-repo-url>#${PKG_SRC_DIR}#g"                       Makefile
    sed -i "s#<category>#${CATEGORY}#g"                                Makefile
    sed -i "s#<submenu>#${SUBMENU}#g"                                  Makefile
    sed -i "s#<title>#${TITLE}#g"                                      Makefile
    sed -i "s#<description>#${DESCRIPTION}#g"                          Makefile

    cd - > /dev/null
}

function FUNC_create_new_source(){
    FUNC_is_folder_existed "${PKG_SRC_DIR}"
    FUNC_create_folder "${PKG_SRC_DIR}"

    cd "${PKG_SRC_DIR}"
    git archive --remote="${REMOTE_URL}" dev-method-impl | tar -x

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
    
    cd - > /dev/null
}

function FUNC_register_local_feed(){
    # openwrt 
    cd ${OPENWRT_DIR}
    
    feed_expr="src-link ${FEED_NAME} ${FEED_DIR}"
    
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

    WORKSPACE="$(pwd)/workspace"
    PKG_SRC_DIR="${WORKSPACE}/SOURCES/${PKG_NAME}"
    FEED_DIR="${WORKSPACE}/FEEDS/${FEED_NAME}"
    PKG_FEED_DIR="${WORKSPACE}/FEEDS/${FEED_NAME}/${PKG_NAME}"

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

function FUNC_convert_git_url(){
    local url=$1

    if [[ $url == *".git"* ]]; then
        PKG_SOURCE_URL_GIT=${url}
    elif [[ $url == *"archive"* ]]; then
        PKG_SOURCE_URL_ARC=${url}
        PKG_SOURCE_URL_GIT=${url/\/-\/archive\/*/.git}
    fi

}

function FUNC_create_source(){
    FUNC_is_folder_existed "${PKG_SRC_DIR}"
    FUNC_create_folder "${PKG_SRC_DIR}"
   
    # Restore Makefile content when overwrite situation
    if [[ $FLAG_OVERWRITE == "1" ]]; then
        cp ${OPENWRT_PKG_DIR}/.Makefile.origin ${OPENWRT_PKG_DIR}/Makefile
        rm ${OPENWRT_PKG_DIR}/.Makefile.origin
    fi

    cd ${PKG_SRC_DIR}

    local pkg_source_url=$( sed -E -n "s#.?PKG_SOURCE_URL.?=(.*)#\1#p" ${OPENWRT_PKG_DIR}/Makefile )
    local pkg_version=$(    sed -E -n "s#.?PKG_VERSION.?=(.*)#\1#p" ${OPENWRT_PKG_DIR}/Makefile    )

    echo "pkg_source_url=${pkg_source_url}"
    
    FUNC_convert_git_url ${pkg_source_url}

    echo "git clone ${PKG_SOURCE_URL_GIT}"

    git clone ${PKG_SOURCE_URL_GIT} .
    git checkout -b dev ${pkg_version}
}

function FUNC_redirect_src_pkg_url(){

    cd ${OPENWRT_PKG_DIR}

    cp Makefile .Makefile.origin
    sed -i "/^PKG_SOURCE_URL/ s/^/# /"                                  Makefile
    sed -i "/^PKG_SOURCE:=/ s/^/# /"                                    Makefile
    sed -i "/^PKG_HASH:=/ s/^/# /"                                      Makefile
    sed -i "/^PKG_BUILD_DIR:=/ s/^/# /"                                 Makefile
    sed -i "/^PKG_LICENSE:=/ s/^/# /"                                   Makefile
    sed -i "/^PKG_LICENSE_FILES:=/ s/^/# /"                             Makefile
    sed -i "/^PKG_RELEASE:=/ s/^/# /"                                   Makefile

    sed -i "/^# PKG_SOURCE_URL/ a PKG_SOURCE_URL:=file://${PKG_SRC_DIR}" Makefile
    sed -i "/^PKG_SOURCE_URL/ a PKG_SOURCE_PROTO:=git"                   Makefile
    sed -i "/^PKG_SOURCE_URL/ a PKG_SOURCE_VERSION:=dev"                 Makefile
}

function FUNC_run_modify_package_process(){

    SUB_COMMAND=$1
    OPENWRT_PKG_DIR=$2

    WORKSPACE="$(pwd)/workspace"
    PKG_NAME=${OPENWRT_PKG_DIR##*/}
    PKG_SRC_DIR="${WORKSPACE}/SOURCES/${PKG_NAME}"


    FUNC_create_source
    FUNC_redirect_src_pkg_url
}


###
# MAIN
###

SUB_COMMAND=$1

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
        OPENWRT_PKG_DIR=$(realpath $2)
        FUNC_run_modify_package_process ${SUB_COMMAND} ${OPENWRT_PKG_DIR}
        ;;
    *)
        HELP
        exit 1
        ;;
esac
