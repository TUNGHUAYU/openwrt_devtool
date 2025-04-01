
function FUNC_create_new_pkg(){

    # tui: reference Makefile selection
    local list="$( find -L ${DEVTOOL_DIR}/.devtool/ref-Makefile -iname Makefile* )"
    FUNC_tui_select \
    "${list}" \
    "${DEVTOOL_DIR}/.devtool/ref-Makefile/" \
    "Please select Makefile style:" \
    "" \
    "" \
    "No. Makefile-Type Makefile-Path"

    local reference_make_path=${RESULT}

    # initail ( prepare environment )
    local dir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/${PKG_NAME}"
    FUNC_is_folder_existed "${dir}"
    FUNC_create_folder "${dir}"

    # copy reference Makefile
    cd "${dir}"
    cp ${reference_make_path} Makefile

    # substitute process 
    # todo: move this process into target reference Makefile folder
    # The ref-Makefile folder will store:
    # 1. Makefile
    # 2. Translate script

    # dry-run substitute work
    sed -n "s#<pkg-name>#${PKG_NAME}#p"                                Makefile
    sed -n "s#<repo-branch>#dev#p"                                     Makefile
    sed -n "s#<local-repo-url>#${DEVTOOL_SRC_DIR}#p"                   Makefile
    sed -n "s#<category>#${CATEGORY}#p"                                Makefile
    sed -n "s#<submenu>#${SUBMENU}#p"                                  Makefile
    sed -n "s#<title>#${TITLE}#p"                                      Makefile
    sed -n "s#<description>#${DESCRIPTION}#p"                          Makefile
    
    # execute substitute work
    sed -i "s#<pkg-name>#${PKG_NAME}#g"                                Makefile
    sed -i "s#<repo-branch>#dev#g"                                     Makefile
    sed -i "s#<local-repo-url>#${DEVTOOL_SRC_DIR}#g"                   Makefile
    sed -i "s#<category>#${CATEGORY}#g"                                Makefile
    sed -i "s#<submenu>#${SUBMENU}#g"                                  Makefile
    sed -i "s#<title>#${TITLE}#g"                                      Makefile
    sed -i "s#<description>#${DESCRIPTION}#g"                          Makefile

    cd - > /dev/null
}

function FUNC_create_new_pkg_source(){

    # tui: reference source selection
    local list="$( find -L ${DEVTOOL_DIR}/.devtool/ref-sources/ -mindepth 1 -maxdepth 1 -type d  )"

    FUNC_tui_select \
    "${list}" \
    "${DEVTOOL_DIR}/.devtool/ref-sources/" \
    "Please select sample source:" \
    "" \
    "" \
    "No. Source_Name Source-Path"

    local reference_source_path=${RESULT}

    #
    local dir=${DEVTOOL_SRC_DIR}
    FUNC_is_folder_existed "${dir}"
    FUNC_create_folder "${dir}"

    # copy reference source
    cd "${dir}"
    cp -r ${reference_source_path}/. .

    # go to .translate folder
    if [[ -d .translate/ ]]; then
        cd .translate/
        echo "test: $(pwd)"
        bash gen_translate_script.sh ${PKG_NAME}
        bash translate.cmd.sh
        cd ../
    fi

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
    
    local feed_expr="src-link ${FEED_NAME} ${DEVTOOL_FEED_DIR}"
    
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

function FUNC_action_new(){

    #
    PKG_NAME=$1
    
    #
    DEVTOOL_SRC_DIR="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    DEVTOOL_FEED_DIR="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}"

    # Determin PKG_TYPE
    FUNC_check_pkg_devloping

    # Check if the package hasn't been developed
    case "${PKG_TYPE}" in
        none )
            # process
            FUNC_create_new_pkg
            FUNC_create_new_pkg_source
            FUNC_register_local_feed
            ;;
            
        * )
            echo "ERROR: package has been developed!!"
            exit ${ERROR_NEW_EXISTED_PKG}
            ;;
    esac
}
