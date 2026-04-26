
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

function FUNC_read_pkg_var(){
    local name=$1
    local file_path=${2:-${OPENWRT_PKG_DIR}/Makefile}

    RESULT=$(sed -E -n "s|^[[:space:]]*${name}[[:space:]]*:?=[[:space:]]*(.*)|\1|p" "${file_path}" | head -n 1)
}

function FUNC_resolve_pkg_expr(){
    local expr=$1

    expr=${expr//\$\(PKG_NAME\)/${PKG_NAME}}
    expr=${expr//\$\(PKG_VERSION\)/${PKG_SOURCE_URL_GIT_BRANCH}}
    expr=${expr//\$\{PKG_NAME\}/${PKG_NAME}}
    expr=${expr//\$\{PKG_VERSION\}/${PKG_SOURCE_URL_GIT_BRANCH}}
    RESULT=${expr}
}

function FUNC_setup_download_pl(){
    local utils_dir="${DEVTOOL_DIR}/.devtool/openwrt/utils"
    local src="${OPENWRT_DIR}/scripts/download.pl"
    local dst="${utils_dir}/download.pl"
    local mirrors_src="${OPENWRT_DIR}/scripts/projectsmirrors.json"
    local mirrors_dst="${utils_dir}/projectsmirrors.json"

    if [[ ! -f "${src}" ]]; then
        echo "ERROR: OpenWrt download.pl not found: ${src}"
        return ${ERROR_FILE_NO_EXIST}
    fi
    if [[ ! -f "${mirrors_src}" ]]; then
        echo "ERROR: OpenWrt projectsmirrors.json not found: ${mirrors_src}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    mkdir -p "${utils_dir}"
    ln -sfn "${src}" "${dst}"
    ln -sfn "${mirrors_src}" "${mirrors_dst}"
    RESULT=${dst}
}

function FUNC_find_mkhash(){
    local mkhash="${OPENWRT_DIR}/staging_dir/host/bin/mkhash"

    if [[ ! -x "${mkhash}" ]]; then
        echo "ERROR: OpenWrt mkhash not found: ${mkhash}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    RESULT=${mkhash}
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

function FUNC_unpack_source_archive(){
    local path=$1
    local source_file=""
    local archive_path=""
    local tmp_dir=""
    local top_entries=""
    local top_entry_count=0
    local top_entry=""

    source_file=$2
    archive_path="${OPENWRT_DIR}/dl/${source_file}"
    if [[ ! -f "${archive_path}" ]]; then
        echo "ERROR: downloaded source file not found: ${archive_path}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    tmp_dir="${DEVTOOL_WORKSPACE_SRC_DIR}/.tmp-${PKG_NAME}"
    rm -rf "${tmp_dir}"
    mkdir -p "${tmp_dir}"

    case "${source_file}" in
        *.tar.gz|*.tgz)
            tar -xzf "${archive_path}" -C "${tmp_dir}" || return $?
            ;;
        *.tar.bz2|*.tbz|*.tbz2)
            tar -xjf "${archive_path}" -C "${tmp_dir}" || return $?
            ;;
        *.tar.xz|*.txz)
            tar -xJf "${archive_path}" -C "${tmp_dir}" || return $?
            ;;
        *.tar.zst|*.tzst)
            tar --zstd -xf "${archive_path}" -C "${tmp_dir}" || return $?
            ;;
        *.tar)
            tar -xf "${archive_path}" -C "${tmp_dir}" || return $?
            ;;
        *.zip)
            unzip -q "${archive_path}" -d "${tmp_dir}" || return $?
            ;;
        *.cpio)
            ( cd "${tmp_dir}" && cpio -id < "${archive_path}" ) || return $?
            ;;
        *)
            echo "ERROR: unsupported archive type: ${source_file}"
            return ${ERROR_FILE_NO_EXIST}
            ;;
    esac

    top_entries=$(find "${tmp_dir}" -mindepth 1 -maxdepth 1 -print)
    top_entry_count=$(find "${tmp_dir}" -mindepth 1 -maxdepth 1 -print | wc -l)
    if [[ ${top_entry_count} -eq 0 ]]; then
        echo "ERROR: archive is empty: ${archive_path}"
        return ${ERROR_FILE_NO_EXIST}
    fi

    if [[ ${top_entry_count} -eq 1 ]]; then
        top_entry=${top_entries}
        if [[ -d ${top_entry} ]]; then
            cp -r "${top_entry}/." "${path}/" || return $?
        else
            cp -r "${top_entry}" "${path}/" || return $?
        fi
    else
        cp -r "${tmp_dir}/." "${path}/" || return $?
    fi

    rm -rf "${tmp_dir}"
}

function FUNC_source_uses_openwrt_download(){
    local source_url=$1
    local source_proto=$2

    RESULT=${RESULT_FALSE}
    case "${source_proto}" in
        git|svn|hg|bzr|cvs|darcs)
            RESULT=${RESULT_TRUE}
            return
            ;;
    esac

    if [[ ${source_url} == git@* ]] || [[ ${source_url} == git://* ]] || [[ ${source_url} == *".git"* ]]; then
        RESULT=${RESULT_TRUE}
    fi
}

function FUNC_create_workspace_src_dir_archive(){
    local path=$1
    local pkg_source=""
    local pkg_hash=""
    local pkg_md5sum=""
    local pkg_mirror_hash=""
    local pkg_source_url_file=""
    local pkg_source_url=""
    local pkg_source_proto=""
    local source_file=""
    local url_file=""
    local download_pl=""
    local mkhash=""
    local download_check_certificate="${DOWNLOAD_CHECK_CERTIFICATE:-n}"

    FUNC_read_pkg_var "PKG_SOURCE"
    pkg_source=${RESULT}
    FUNC_resolve_pkg_expr "${pkg_source}"
    pkg_source=${RESULT}
    if [[ -z ${pkg_source} ]]; then
        echo "ERROR: PKG_SOURCE is required for archive source setup"
        return ${ERROR_FILE_NO_EXIST}
    fi

    FUNC_read_pkg_var "PKG_HASH"
    pkg_hash=${RESULT}
    FUNC_read_pkg_var "PKG_MD5SUM"
    pkg_md5sum=${RESULT}
    FUNC_read_pkg_var "PKG_MIRROR_HASH"
    pkg_mirror_hash=${RESULT}
    [[ -z ${pkg_hash} ]] && pkg_hash=${pkg_md5sum}
    [[ -z ${pkg_hash} ]] && pkg_hash=${pkg_mirror_hash}
    [[ -z ${pkg_hash} ]] && pkg_hash="skip"

    FUNC_read_pkg_var "PKG_SOURCE_URL_FILE"
    pkg_source_url_file=${RESULT}
    FUNC_resolve_pkg_expr "${pkg_source_url_file}"
    pkg_source_url_file=${RESULT}

    FUNC_read_pkg_var "PKG_SOURCE_URL"
    pkg_source_url=${RESULT}
    FUNC_read_pkg_var "PKG_SOURCE_PROTO"
    pkg_source_proto=${RESULT}

    source_file=${pkg_source}
    url_file=${pkg_source_url_file}
    [[ -n ${pkg_source_url_file} ]] && source_file=${pkg_source_url_file}

    FUNC_source_uses_openwrt_download "${pkg_source_url}" "${pkg_source_proto}"
    if [[ ${RESULT} == ${RESULT_TRUE} ]]; then
        echo "make -C ${OPENWRT_DIR} package/${PKG_PATH}/download"
        make -C "${OPENWRT_DIR}" "package/${PKG_PATH}/download" || return $?
        source_file=${pkg_source}
    else
        FUNC_setup_download_pl || return $?
        download_pl=${RESULT}
        FUNC_find_mkhash || return $?
        mkhash=${RESULT}

        echo "${download_pl} ${OPENWRT_DIR}/dl ${source_file} ${pkg_hash} ${url_file} ${PKG_SOURCE_URL_TARBALL}"
        DOWNLOAD_CHECK_CERTIFICATE="${download_check_certificate}" \
        DOWNLOAD_TOOL_CUSTOM="${DOWNLOAD_TOOL_CUSTOM:-}" \
        TOPDIR="${OPENWRT_DIR}" \
        MKHASH="${mkhash}" \
        "${download_pl}" "${OPENWRT_DIR}/dl" "${source_file}" "${pkg_hash}" "${url_file}" "${PKG_SOURCE_URL_TARBALL}" || return $?
    fi

    FUNC_unpack_source_archive "${path}" "${source_file}" || return $?
    FUNC_init_workspace_src_git "${path}" || return $?
}

function FUNC_create_workspace_src_dir(){

    local path="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    local old_pwd=$(pwd)
    local status=0

    FUNC_is_folder_existed "${path}"
    FUNC_create_folder "${path}"
    local pkg_source_url=$( sed -E -n "s|^[[:space:]]*PKG_SOURCE_URL[[:space:]]*:?=[[:space:]]*(.*)|\1|p" ${OPENWRT_PKG_DIR}/Makefile | head -n 1 )

    # Parse url 
    echo "FUNC_parse_url ${pkg_source_url}"
    FUNC_parse_url ${pkg_source_url}
    
    # Move to source director
    cd "${path}" || return $?

    case "${PKG_SOURCE_URL_TYPE}" in
        git|archive|tarball)
            FUNC_create_workspace_src_dir_archive "${path}"
            status=$?
            ;;
        *)
            echo "ERROR: unsupported PKG_SOURCE_URL=${pkg_source_url}"
            status=${ERROR_NOT_GIT_REPO}
            ;;
    esac

    cd "${old_pwd}" || return $?
    if [[ ${status} -ne 0 ]]; then
        rm -rf "${path}" "${DEVTOOL_WORKSPACE_SRC_DIR}/.tmp-${PKG_NAME}"
        return ${status}
    fi
}

function FUNC_symlink_pkg_dir(){

    rm ${OPENWRT_PKG_DIR}
    ln -sf "${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}" ${OPENWRT_PKG_DIR}

}

function FUNC_redirect_src_pkg_url(){

    local path="${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    local old_pwd=$(pwd)


    cd "${DEVTOOL_WORKSPACE_PKG_DIR}/${PKG_PATH}"

    # comment only source and package identity variables replaced by devtool
    sed -i -E "/^[[:space:]]*(PKG_NAME|PKG_VERSION|PKG_RELEASE|PKG_SOURCE|PKG_SOURCE_URL|PKG_SOURCE_PROTO|PKG_SOURCE_VERSION|PKG_SOURCE_URL_FILE|PKG_SOURCE_SUBDIR|PKG_SOURCE_DATE|PKG_SOURCE_MIRROR|PKG_SOURCE_SUBMODULES|PKG_HASH|PKG_MD5SUM|PKG_MIRROR_HASH)[[:space:]]*:?=/ s/^/# /" Makefile

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

    cd "${old_pwd}" || return $?
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
        FUNC_read_pkg_var "PKG_SOURCE"
        FUNC_resolve_pkg_expr "${RESULT}"
        echo "download tarball source with ${DEVTOOL_DIR}/.devtool/openwrt/utils/download.pl"
        echo "download destination: ${OPENWRT_DIR}/dl/${RESULT}"
        echo "unpack source into ${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    else
        echo "download source archive with make -C ${OPENWRT_DIR} package/${PKG_PATH}/download"
        echo "unpack source archive into ${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    fi
    echo "create ref-base branch at ${PKG_SOURCE_URL_GIT_BRANCH}"
    echo "checkout dev branch from ref-base"
    echo "replace OpenWrt package with symlink to workspace package"
    echo "rewrite Makefile with PKG_SOURCE_URL:=file://${DEVTOOL_WORKSPACE_SRC_DIR}/${PKG_NAME}"
    echo "rewrite Makefile with PKG_SOURCE_VERSION:=ref-base"
    echo "preserve build metadata such as PKG_INSTALL, PKG_FIXUP, and PKG_BUILD_FLAGS"
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
