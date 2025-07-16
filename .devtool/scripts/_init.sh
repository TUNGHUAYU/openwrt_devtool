# intial work
# Enter the path of OPENWRT workspace
# Set environment OPENWRT_DIR value
FUNC_init(){
    read -e -p "Enter OPENWRT_DIR="
    [[ -n $REPLY ]] && echo "OPENWRT_DIR=${REPLY}"
    [[ -n $REPLY ]] && eval "OPENWRT_DIR=$(realpath ${REPLY})"
}
