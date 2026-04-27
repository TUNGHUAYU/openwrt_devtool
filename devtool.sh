#!/bin/bash

###
# Define very first and important variables
###
DEVTOOL_DIR=$(dirname "$0")
DEVTOOL_DIR=$(realpath "${DEVTOOL_DIR}")
DEVTOOL_DIR=${DEVTOOL_DIR}
DEVTOOL_CONF_PATH_FILE=${DEVTOOL_DIR}/.devtool/configs/path.conf

###
# Load configuration scripts
###

source ${DEVTOOL_CONF_PATH_FILE}
source ${DEVTOOL_CONF_CORE_FILE}
source ${DEVTOOL_CONF_VERSION_FILE}

###
# Load system need scripts
###

source ${DEVTOOL_SCRIPT_CORE_FILE}
source ${DEVTOOL_SCRIPT_INIT_FILE}
source ${DEVTOOL_SCRIPT_UTILS_FILE}

###
# HELP MESSAGE
###

function HELP_BEGIN(){
    devtool_print ${LOG_CORE} ""
}

function HELP_END(){
    devtool_print ${LOG_CORE} ""
}

function HELP_PRINT_GREEN(){
    local format=$1
    local green=""
    local reset=""

    shift
    printf -v green "%b" "${GREEN}"
    printf -v reset "%b" "${NC}"
    devtool_print ${LOG_CORE} "${green}${format}${reset}" "$@"
}

function HELP_MAIN(){
    HELP_BEGIN
    devtool_print ${LOG_CORE} "OpenWrt Devtool"
    devtool_print ${LOG_CORE} "Version: ${VERSION}"
    devtool_print ${LOG_CORE} ""
    HELP_PRINT_GREEN "Usage: ./devtool.sh <command> [options]"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Commands:"
    devtool_print ${LOG_CORE} "  %-10s %s" "list" "List packages tracked in the workspace."
    devtool_print ${LOG_CORE} "  %-10s %s" "new" "Create a new devtool package."
    devtool_print ${LOG_CORE} "  %-10s %s" "modify" "Modify an existing OpenWrt package."
    devtool_print ${LOG_CORE} "  %-10s %s" "patch" "Generate OpenWrt patches from source commits."
    devtool_print ${LOG_CORE} "  %-10s %s" "finish" "Finalize package work into finished output or OpenWrt patches."
    devtool_print ${LOG_CORE} "  %-10s %s" "abort" "Abort a selected devtool package."
    devtool_print ${LOG_CORE} "  %-10s %s" "help" "Show this help message."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Notes:"
    devtool_print ${LOG_CORE} "  Run ./devtool.sh <command> help for command-specific arguments."
    devtool_print ${LOG_CORE} "  Builds run through the configured OpenWrt tree."
    HELP_END
}

function HELP_LIST(){
    HELP_BEGIN
    HELP_PRINT_GREEN "Usage: ./devtool.sh list"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Lists new and modified packages tracked in the devtool workspace."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Example:"
    HELP_PRINT_GREEN "  ./devtool.sh list"
    HELP_END
}

function HELP_NEW(){
    HELP_BEGIN
    HELP_PRINT_GREEN "Usage: ./devtool.sh new <pkg-name> [<git-url>]"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Arguments:"
    devtool_print ${LOG_CORE} "  %-14s %s" "<pkg-name>" "Name of the new package to create."
    devtool_print ${LOG_CORE} "  %-14s %s" "[<git-url>]" "Optional Git repository URL to use as source."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Examples:"
    HELP_PRINT_GREEN "  ./devtool.sh new demo_plugin"
    HELP_PRINT_GREEN "  ./devtool.sh new demo_plugin https://example.com/demo.git"
    HELP_END
}

function HELP_MODIFY(){
    HELP_BEGIN
    HELP_PRINT_GREEN "Usage: ./devtool.sh modify [<pkg-pattern>] [--dry-run]"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Arguments:"
    devtool_print ${LOG_CORE} "  %-16s %s" "[<pkg-pattern>]" "Optional package name or path pattern used to filter package selection."
    devtool_print ${LOG_CORE} "  %-16s %s" "[--dry-run]" "Show the planned workspace changes without modifying package state."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Examples:"
    HELP_PRINT_GREEN "  ./devtool.sh modify"
    HELP_PRINT_GREEN "  ./devtool.sh modify libcap-ng --dry-run"
    HELP_END
}

function HELP_PATCH(){
    HELP_BEGIN
    HELP_PRINT_GREEN "Usage: ./devtool.sh patch [<pkg-pattern>] [<base-ref>]"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Arguments:"
    devtool_print ${LOG_CORE} "  %-16s %s" "[<pkg-pattern>]" "Optional modified package name or path pattern used to filter package selection."
    devtool_print ${LOG_CORE} "  %-16s %s" "[<base-ref>]" "Optional git base ref; defaults to package PKG_SOURCE_VERSION, then ref-base."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Notes:"
    devtool_print ${LOG_CORE} "  Without a package pattern, choose from modified packages."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Examples:"
    HELP_PRINT_GREEN "  ./devtool.sh patch"
    HELP_PRINT_GREEN "  ./devtool.sh patch libcap-ng ref-base"
    HELP_END
}

function HELP_ABORT(){
    HELP_BEGIN
    HELP_PRINT_GREEN "Usage: ./devtool.sh abort"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Removes selected generated package work after confirmation."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Example:"
    HELP_PRINT_GREEN "  ./devtool.sh abort"
    HELP_END
}

function HELP_FINISH(){
    HELP_BEGIN
    HELP_PRINT_GREEN "Usage: ./devtool.sh finish [<pkg-pattern>] [--dry-run]"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Arguments:"
    devtool_print ${LOG_CORE} "  %-16s %s" "[<pkg-pattern>]" "Optional devtool package name or path pattern used to filter package selection."
    devtool_print ${LOG_CORE} "  %-16s %s" "[--dry-run]" "Show finished output and cleanup steps without changing package state."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Notes:"
    devtool_print ${LOG_CORE} "  New packages move Makefile and source into workspace/finished/."
    devtool_print ${LOG_CORE} "  Modified packages move generated patches into the OpenWrt package patches directory."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Examples:"
    HELP_PRINT_GREEN "  ./devtool.sh finish"
    HELP_PRINT_GREEN "  ./devtool.sh finish libcap-ng --dry-run"
    HELP_END
}

function HELP_HELP(){
    HELP_BEGIN
    HELP_PRINT_GREEN "Usage: ./devtool.sh help"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Shows the top-level command overview."
    devtool_print ${LOG_CORE} "Run ./devtool.sh <command> help for command-specific arguments."
    HELP_END
}

###
# MAIN
###

# Check if OPENWRT_DIR assigned value
FUNC_exist_openwrt_dir && \
[[ ${RESULT} == ${RESULT_FALSE} ]] && \
FUNC_init

# Check if OPENWRT_DIR is legal
FUNC_is_openwrt_dir && \
[[ ${RESULT} == ${RESULT_FALSE} ]] && \
exit ${ERROR_FILE_NO_EXIST}

# Check if git config exist
FUNC_check_git_conf && \
[[ ${RESULT} == ${RESULT_NOK} ]] && \
exit ${ERROR_GIT_CONF}

# update ${DEVTOOL_DIR}/.openwrt_dir 
FUNC_remember_openwrt_dir

# Capture all devtool packages 
FUNC_get_new_pkg_list
FUNC_get_mod_pkg_list

# Action Selection
COMMAND=$1
case "${COMMAND}" in 
    list)
        [[ "$2" == "help" ]] && HELP_LIST && exit ${RESULT_OK}
        source ${DEVTOOL_SCRIPT_ACTION_LIST}
        FUNC_action_list
        ;;
    new)
        [[ "$2" == "help" ]] && HELP_NEW && exit ${RESULT_OK}
        source ${DEVTOOL_SCRIPT_ACTION_NEW}
        [[ -z $2 ]] && HELP_NEW && exit ${ERROR_NO_PKG_NAME}
        PKG_NAME=$2
        URL=$3
        FUNC_action_new ${PKG_NAME} ${URL}
        ;;
    modify)
        [[ "$2" == "help" ]] && HELP_MODIFY && exit ${RESULT_OK}
        source ${DEVTOOL_SCRIPT_ACTION_MODIFY}
        if [[ "$2" == "--dry-run" ]]; then
            PKG_NAME_PATTERN=""
            MODIFY_DRY_RUN="--dry-run"
        else
            PKG_NAME_PATTERN=$2
            MODIFY_DRY_RUN=$3
        fi
        FUNC_action_modify "${PKG_NAME_PATTERN}" "${MODIFY_DRY_RUN}"
        ;;
    patch)
        [[ "$2" == "help" ]] && HELP_PATCH && exit ${RESULT_OK}
        source ${DEVTOOL_SCRIPT_ACTION_PATCH}
        PKG_NAME_PATTERN=${2:-}
        BASE_REF=${3:-}
        FUNC_action_patch "${PKG_NAME_PATTERN}" "${BASE_REF}"
        ;;
    finish)
        [[ "$2" == "help" ]] && HELP_FINISH && exit ${RESULT_OK}
        source ${DEVTOOL_SCRIPT_ACTION_PATCH}
        source ${DEVTOOL_SCRIPT_ACTION_FINISH}
        if [[ "$2" == "--dry-run" ]]; then
            PKG_NAME_PATTERN=""
            FINISH_DRY_RUN="--dry-run"
        else
            PKG_NAME_PATTERN=${2:-}
            FINISH_DRY_RUN=${3:-}
        fi
        FUNC_action_finish "${PKG_NAME_PATTERN}" "${FINISH_DRY_RUN}"
        ;;
    abort)
        [[ "$2" == "help" ]] && HELP_ABORT && exit ${RESULT_OK}
        source ${DEVTOOL_SCRIPT_ACTION_ABORT}
        FUNC_action_abort
        ;;
    help)
        [[ "$2" == "help" ]] && HELP_HELP && exit ${RESULT_OK}
        HELP_MAIN
        ;;
    *)
        echo "ILLEGAL COMMAND: ${COMMAND}"
        HELP_MAIN
        exit ${ERROR_ILLEGAL_COMMAND}
        ;;
esac
