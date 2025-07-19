
###
# Utils - uesful functions
###



# devtool print function
# usage: devtool_print <log_level> <string>

devtool_print(){
    local log_leve=$1
    local string=$2

    if [[ ${LOG_LEVEL} -ge ${log_leve} ]]; then
        [[ "${VERBOSE}" == "1" ]] && printf "%s: %s\n" ${LOG_NAME_LIST[${log_leve}]} "${string}"
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


# TUI: list options filtering by given pattern and assign value to the specific 
# usage:
# $1: list          : list all options
# $2: search_path   : target search path
# $3: message       : tui message
# $4: format        : title format 
# $5: title         : manual title
function FUNC_tui_select(){
    local list=($1)
    local search_path=$2
    local message=$3
    local format=${4:-'%-30s|%-50s \n'}
    local title=${6:-"PKG-NAME PKG-PATH"}

    #
    [[ ${#list[@]} == 0 ]] && \
    devtool_print "${LOG_CORE}" "No matching package!!" && \
    exit ${ERROR_NO_MATCHING_PKG}

    # TUI: List
    
    echo ""
    echo "search_path: ${search_path}"
    echo ""

    local i=1;
    echo "---"
    printf "|%-5s|${format}" "No." ${title}
    echo
    for p in ${list[@]}
    do
        printf "|%-5d|${format}" "${i}" "${p##*/}" "${p/${search_path}/\$\{search_path\}\/}"
        i=$((i+1))
    done
    echo "---"

    # TUI: Select
    # list is 0-starting
    echo "${message}"
    read -e -p "Select: "
    local index=$((${REPLY}-1))

    echo 
    echo "Select: ${list[${index}]/${search_path}/}"
    echo 

    RESULT=${list[${index}]}
}


# Check git config ( must include name and email )
function FUNC_check_git_conf(){
    # Get name and email 
    local author_name=$(git config --global user.name)
    local author_email=$(git config --global user.email)

    # Check
    if [ -z ${author_name} ] || [ -z ${author_email} ]; then
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