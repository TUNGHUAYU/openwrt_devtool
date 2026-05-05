
function FUNC_create_new_pkg(){

    # tui: reference Makefile selection
    local list="$( find -L ${DEVTOOL_DIR}/.devtool/ref-Makefile -iname Makefile* | sort )"
    FUNC_tui_select \
        "${list}" \
        --search-path "${DEVTOOL_DIR}/.devtool/ref-Makefile/" \
        --message "Please select Makefile style:" \
        --title "MAKEFILE STYLE|MAKEFILE PATH"

    local reference_make_path=${RESULT}

    # initail ( prepare environment )
    local dir="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/${PKG_NAME}"
    FUNC_is_folder_existed "${dir}"
    FUNC_create_folder "${dir}"

    # copy reference Makefile
    cd "${dir}" || return $?
    cp "${reference_make_path}" Makefile || return $?

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

    cd - > /dev/null || return $?
}

function FUNC_create_new_pkg_source(){

    # tui: reference source selection
    local list="$( find -L ${DEVTOOL_DIR}/.devtool/ref-sources/ -mindepth 1 -maxdepth 1 -type d | sort )"

    FUNC_tui_select \
        "${list}" \
        --search-path "${DEVTOOL_DIR}/.devtool/ref-sources/" \
        --message "Please select sample source:" \
        --title "SOURCE|SOURCE PATH"

    local reference_source_path=${RESULT}

    #
    local dir=${DEVTOOL_SRC_DIR}
    FUNC_is_folder_existed "${dir}"
    FUNC_create_folder "${dir}"

    # copy reference source
    cd "${dir}" || return $?
    cp -r "${reference_source_path}/." . || return $?

    # go to .translate folder
    if [[ -d .translate/ ]]; then
        cd .translate/
        echo "test: $(pwd)"
        bash gen_translate_script.sh ${PKG_NAME} || return $?
        bash translate.cmd.sh || return $?
        cd ../ || return $?
    fi

    # initial git
    git init || return $?
    git add . || return $?
    git commit -m "first commit" || return $?
    git checkout -b dev || return $?
    
    cd - > /dev/null || return $?
}

function FUNC_create_new_pkg_source_remote(){

    #
    local dir=${DEVTOOL_SRC_DIR}
    FUNC_is_folder_existed "${dir}"
    FUNC_create_folder "${dir}"

    # copy reference source
    cd "${dir}" || return $?
    #cp -r ${reference_source_path}/. .
    git clone "${URL}" . || return $?
    git checkout -B dev || return $?
    
    cd - > /dev/null || return $?
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

function FUNC_cleanup_new_pkg_workspace(){
    rm -rf "${DEVTOOL_SRC_DIR}" "${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}/${PKG_NAME}"
}

function FUNC_action_new(){

    # variables
    PKG_NAME=$1
    URL=${2:-}
    
    # Determin PKG_TYPE
    FUNC_check_pkg_type ${URL}
    DEVTOOL_SRC_DIR="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    DEVTOOL_FEED_DIR="${DEVTOOL_WORKSPACE_FEED_DIR}/${FEED_NAME}"

    devtool_print ${LOG_INFO} "PKG_TYPE=$PKG_TYPE"

    # Check if the package hasn't been developed
    case "${PKG_TYPE}" in
        none )
            # process
            FUNC_create_new_pkg
            FUNC_create_new_pkg_source
            FUNC_register_local_feed
            ;;
        
        remote-git )
            FUNC_check_url_is_git_repo "${URL}"
            if [ "$RESULT" == "$RESULT_NOK" ]; then 
                return ${ERROR_NOT_GIT_REPO}
            fi
            FUNC_create_new_pkg || { local status=$?; FUNC_cleanup_new_pkg_workspace; return ${status}; }
            FUNC_create_new_pkg_source_remote || { local status=$?; FUNC_cleanup_new_pkg_workspace; return ${status}; }
            FUNC_register_local_feed || { local status=$?; FUNC_cleanup_new_pkg_workspace; return ${status}; }
            ;;

        * )
            echo "ERROR: package has been developed!!"
            exit ${ERROR_NEW_EXISTED_PKG}
            ;;
    esac
}
