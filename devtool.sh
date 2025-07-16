#!/bin/bash

###
# Define very first and important variables
###
DEVTOOL_DIR=${0%/*.sh}
DEVTOOL_DIR=$(realpath ${DEVTOOL_DIR})
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
    devtool_print ${LOG_CORE} "Usage: ./devtool <command> [<options>]"
    devtool_print ${LOG_CORE} "version: ${VERSION}"
    devtool_print ${LOG_CORE} ""
    devtool_print ${LOG_CORE} "Commands: "
    devtool_print ${LOG_CORE} "---"
    devtool_print ${LOG_CORE} "new    <pkg-name>      : New devtool package. <pkg-name>: new package name" 
    devtool_print ${LOG_CORE} "modify [<pkg-pattern>] : Modify openwrt package. <pkg-pattern>: filter by given pattern"
    devtool_print ${LOG_CORE} "abort                  : Abort developing devtool package"
    devtool_print ${LOG_CORE} "list                   : List developing devtool packages"
    devtool_print ${LOG_CORE} "---"
}

###
# MAIN
###

# Check if OPENWRT_DIR assigned value
FUNC_exist_openwrt_dir && \
[[ ${RESULT} == ${RESULT_FLASE} ]] && \
FUNC_init

# Check if OPENWRT_DIR is legal
FUNC_is_openwrt_dir && \
[[ ${RESULT} == ${RESULT_FLASE} ]] && \
exit ${ERROR_FILE_NO_EXIST}

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
        FUNC_action_new ${PKG_NAME}
        ;;
    modify)
        source ${DEVTOOL_SCRIPT_ACTION_MODIFY}
        PKG_NAME_PATTERN=$2
        FUNC_action_modify ${PKG_NAME_PATTERN}
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
