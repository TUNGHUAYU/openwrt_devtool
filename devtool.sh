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

function HELP(){
    devtool_print ${LOG_CORE} "OpenWrt Devtool"
    devtool_print ${LOG_CORE} "Version: ${VERSION}"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Usage: ./devtool.sh <command> [options]"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Commands:"
    devtool_print ${LOG_CORE} "  %-34s %s" "new <pkg-name> [<http-url>]" "Create a new devtool package."
    devtool_print ${LOG_CORE} "  %-34s %s" "modify [<pkg-pattern>] [--dry-run]" "Modify an existing OpenWrt package."
    devtool_print ${LOG_CORE} "  %-34s %s" "patch <pkg-pattern> [<base-ref>]" "Generate OpenWrt patches from source commits."
    devtool_print ${LOG_CORE} "  %-34s %s" "abort" "Abort a selected devtool package."
    devtool_print ${LOG_CORE} "  %-34s %s" "list" "List packages tracked in the workspace."
    devtool_print ${LOG_CORE} "  %-34s %s" "help" "Show this help message."
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Examples:"
    devtool_print ${LOG_CORE} "  ./devtool.sh list"
    devtool_print ${LOG_CORE} "  ./devtool.sh modify libcap-ng --dry-run"
    devtool_print ${LOG_CORE} "  ./devtool.sh patch libcap-ng ref-base"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Notes:"
    devtool_print ${LOG_CORE} "  Builds run through the configured OpenWrt tree."
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
        source ${DEVTOOL_SCRIPT_ACTION_LIST}
        FUNC_action_list
        ;;
    new)
        source ${DEVTOOL_SCRIPT_ACTION_NEW}
        [[ -z $2 ]] && HELP && exit ${ERROR_NO_PKG_NAME}
        PKG_NAME=$2
        URL=$3
        FUNC_action_new ${PKG_NAME} ${URL}
        ;;
    modify)
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
        source ${DEVTOOL_SCRIPT_ACTION_PATCH}
        PKG_NAME_PATTERN=${2:-}
        BASE_REF=${3:-}
        FUNC_action_patch "${PKG_NAME_PATTERN}" "${BASE_REF}"
        ;;
    abort)
        source ${DEVTOOL_SCRIPT_ACTION_ABORT}
        FUNC_action_abort
        ;;
    help)
        HELP
        ;;
    *)
        echo "ILLEGAL COMMAND: ${COMMAND}"
        HELP
        exit ${ERROR_ILLEGAL_COMMAND}
        ;;
esac
