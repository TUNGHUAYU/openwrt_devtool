

function FUNC_action_list(){

    local count=0
    local type=""
    local pkg_name=""
    local format="|%-03s|%-30s|%-10s|%-50s"
    local _format="|%-03d|%-30s|%-10s|%-50s"
    devtool_print "${LOG_CORE}" ""
    devtool_print "${LOG_CORE}" "${format}" "No." "PKG-NAME" "TYPE" "PKG-PATH"
    devtool_print "${LOG_CORE}" ""

    for p in ${NEW_PKG_LIST}
    do
        type="new"
        pkg_name="${p##*/}"
        count=$(( count + 1 ))
        devtool_print "${LOG_CORE}" "${_format}" "${count}" "${p##*/}" "${type}" "${p/${DEVTOOL_DIR}\//}"
    done

    for p in ${MOD_PKG_LIST}
    do
        type="modify"
        pkg_name="${p##*/}"
        count=$(( count + 1 ))
        devtool_print "${LOG_CORE}" "${_format}" "${count}" "${p##*/}" "${type}" "${p/${DEVTOOL_DIR}\//}"
    done
}
