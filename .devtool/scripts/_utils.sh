
###
# Utils - uesful functions
###



# devtool print function
# usage: devtool_print <log_level> <format> [args...]

devtool_print(){
    local log_leve=$1
    local format=$2
    local string=""

    shift 2
    if [[ $# -eq 0 ]]; then
        string=${format}
    else
        printf -v string "${format}" "$@"
    fi

    if [[ ${LOG_LEVEL} -ge ${log_leve} ]]; then
        [[ "${VERBOSE}" == "1" ]] && printf "%s: %s\n" "${LOG_NAME_LIST[${log_leve}]}" "${string}"
        [[ "${VERBOSE}" == "0" ]] && printf "%s\n" "${string}"
    fi
}

# devtool cd function
# usage: devtool_cd <dst_path>
devtool_cd(){
    local path=$1

    local src_path=$(pwd)
    local dst_path=$(realpath $path)

    devtool_print ${LOG_INFO} "Move to \"${dst_path}\""
}

# write environment value into config file
# usage: FUNC_write_env_value <pattern> <newval> <conf_file_path>
FUNC_write_env_value(){
    local pattern=$1
    local newval=$2
    local file_path=$3

    # check file_path 
    if [[ ! -f ${file_path} ]]; then
        RESULT=${RESULT_ERROR}
        return ${ERROR_FILE_NO_EXIST}
    fi

    #
    [[ ${VERBOSE} == 1 ]] && \
    sed "s|^\(${pattern}[^=]*\)=.*|\1=${newval}|g" ${file_path} | diff -u ${file_path} - 

    sed -i "s|^\(${pattern}[^=]*\)=.*|\1=${newval}|" ${file_path}

    eval "${pattern}=${newval}"
}

# check if folder is existed
# usage:
function FUNC_is_folder_existed(){
    local dir=$1

    if [[ -d ${dir} ]]; then
        read -p "overwrite ${dir}?(y/n)"
        if [[ $REPLY == "y" ]]; then
            rm ${dir} -rf
        else
            exit 1
        fi
    fi
}

# create new folder
# usage:
function FUNC_create_folder(){
    local dir=$1

    devtool_print "${LOG_INFO}" "Create folder \"${dir}\""
    # echo "Create folder \"${dir}\""
    mkdir -p ${dir}
}


# TUI: list options and assign the selected value to RESULT.
# usage:
# FUNC_tui_select "<items>" \
#   --search-path "<path-prefix>" \
#   --message "<prompt>" \
#   --format "<printf-format>" \
#   --title "<header columns>" \
#   --item-mode path|plain
function FUNC_tui_select(){
    local raw_list=$1
    local list=(${raw_list})
    local search_path=""
    local message="Please select:"
    local format='%-30s|%-50s'
    local title="PKG-NAME PKG-PATH"
    local title_columns=()
    local item_mode="path"
    local format_set=${RESULT_FALSE}
    local title_set=${RESULT_FALSE}
    local selected=""
    local display_name=""
    local display_path=""

    shift
    if [[ ${1:-} == --* ]]; then
        while [[ $# -gt 0 ]]
        do
            case "$1" in
                --search-path)
                    [[ $# -lt 2 ]] && devtool_print "${LOG_ERRO}" "Missing value for menu option: %s" "$1" && RESULT="" && return ${ERROR_ILLEGAL_COMMAND}
                    search_path=$2
                    shift 2
                    ;;
                --message)
                    [[ $# -lt 2 ]] && devtool_print "${LOG_ERRO}" "Missing value for menu option: %s" "$1" && RESULT="" && return ${ERROR_ILLEGAL_COMMAND}
                    message=$2
                    shift 2
                    ;;
                --format)
                    [[ $# -lt 2 ]] && devtool_print "${LOG_ERRO}" "Missing value for menu option: %s" "$1" && RESULT="" && return ${ERROR_ILLEGAL_COMMAND}
                    format=$2
                    format_set=${RESULT_TRUE}
                    shift 2
                    ;;
                --title)
                    [[ $# -lt 2 ]] && devtool_print "${LOG_ERRO}" "Missing value for menu option: %s" "$1" && RESULT="" && return ${ERROR_ILLEGAL_COMMAND}
                    title=$2
                    title_set=${RESULT_TRUE}
                    shift 2
                    ;;
                --item-mode)
                    [[ $# -lt 2 ]] && devtool_print "${LOG_ERRO}" "Missing value for menu option: %s" "$1" && RESULT="" && return ${ERROR_ILLEGAL_COMMAND}
                    item_mode=$2
                    shift 2
                    ;;
                *)
                    devtool_print "${LOG_ERRO}" "Unknown menu option: %s" "$1"
                    RESULT=""
                    return ${ERROR_ILLEGAL_COMMAND}
                    ;;
            esac
        done
    else
        search_path=${1:-}
        message=${2:-${message}}
        format=${3:-${format}}
        title=${4:-${5:-${title}}}
    fi

    if [[ ${item_mode} == "plain" ]]; then
        [[ ${format_set} == ${RESULT_FALSE} ]] && format='%-50s'
        [[ ${title_set} == ${RESULT_FALSE} ]] && title="ITEM"
    elif [[ ${item_mode} != "path" ]]; then
        devtool_print "${LOG_ERRO}" "Unknown menu item mode: %s" "${item_mode}"
        RESULT=""
        return ${ERROR_ILLEGAL_COMMAND}
    fi
    if [[ ${title} == *"|"* ]]; then
        IFS='|' read -r -a title_columns <<< "${title}"
    else
        read -r -a title_columns <<< "${title}"
    fi

    if [[ ${#list[@]} -eq 0 ]]; then
        devtool_print "${LOG_CORE}" "No matching package!!"
        RESULT=""
        return ${ERROR_NO_MATCHING_PKG}
    fi

    # TUI: List
    
    if [[ ${item_mode} == "path" ]]; then
        echo ""
        echo "search_path: ${search_path}"
        echo ""
    fi

    local i=1;
    devtool_print "${LOG_CORE}" ""
    devtool_print "${LOG_CORE}" "---"
    devtool_print "${LOG_CORE}" "|%-5s|${format}" "No." "${title_columns[@]}"
    devtool_print "${LOG_CORE}" ""
    for p in ${list[@]}
    do
        case "${item_mode}" in
            plain)
                devtool_print "${LOG_CORE}" "|%-5d|${format}" "${i}" "${p}"
                ;;
            path)
                display_name="${p##*/}"
                if [[ -n ${search_path} ]]; then
                    display_path="${p/${search_path}/\$\{search_path\}\/}"
                else
                    display_path="${p}"
                fi
                devtool_print "${LOG_CORE}" "|%-5d|${format}" "${i}" "${display_name}" "${display_path}"
                ;;
        esac
        i=$((i+1))
    done
    devtool_print "${LOG_CORE}" "---"

    # TUI: Select
    # list is 0-starting
    echo "${message}"
    read -e -p "Select: "
    local index=$((${REPLY}-1))

    if [[ ! ${REPLY} =~ ^[0-9]+$ ]] || [[ ${index} -lt 0 ]] || [[ ${index} -ge ${#list[@]} ]]; then
        devtool_print "${LOG_ERRO}" "Invalid selection: %s" "${REPLY}"
        RESULT=""
        return ${ERROR_ILLEGAL_COMMAND}
    fi

    selected=${list[${index}]}

    echo 
    if [[ ${item_mode} == "path" ]] && [[ -n ${search_path} ]]; then
        echo "Select: ${selected/${search_path}/}"
    else
        echo "Select: ${selected}"
    fi
    echo 

    RESULT=${selected}
}


# Check git config ( must include name and email )
function FUNC_check_git_conf(){
    # Get name and email 
    local author_name=$(git config --global user.name)
    local author_email=$(git config --global user.email)

    # Check
    if [ -z "${author_name}" ] || [ -z "${author_email}" ]; then
        echo "ERROR: No git config name or email"
        echo "please git --global config user.name <name>"
        echo "please git --global config user.email <email>"
        echo "git.name = ${author_name}"
        echo "git.email = ${author_email}"
        RESULT=${RESULT_NOK}
        return
    fi

    # 
    RESULT=${RESULT_OK}
}


function FUNC_check_url_is_git_repo(){

    local url=$1
    RESULT=${RESULT_NOK}

    if git ls-remote $url &> /dev/null; then
        echo "Valid Git repository ${url}"
        RESULT=${RESULT_OK}
    fi
}
