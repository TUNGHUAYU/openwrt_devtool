# intial work
FUNC_init(){

    #
    read -e -p "Enter OPENWRT_DIR="
    [[ -n $REPLY ]] && FUNC_assign_env_value "OPENWRT_DIR" $(realpath $REPLY)
    [[ -n $REPLY ]] && FUNC_write_env_value "OPENWRT_DIR" $(realpath $REPLY) ${DEVTOOL_CONF_PATH_FILE}
}