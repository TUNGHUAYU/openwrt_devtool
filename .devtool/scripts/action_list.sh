

function FUNC_action_list(){

    local count=0
    local type=""
    local pkg_name=""
    local format="|%-03s|%-30s|%-10s|%-50s \n"
    local _format="|%-03d|%-30s|%-10s|%-50s \n"
    printf "${format}" "No." "PKG-NAME" "TYPE" "PKG-PATH"
    printf "${format}" "---" "--------" "----" "-------"

    for p in ${NEW_PKG_LIST}
    do
        type="new"
        pkg_name="${p##*/}"
        count=$(( count + 1 ))
        printf "${_format}" "${count}" "${p##*/}" "${type}" "${p/${DEVTOOL_DIR}\//}"
    done

    for p in ${MOD_PKG_LIST}
    do
        type="modify"
        pkg_name="${p##*/}"
        count=$(( count + 1 ))
        printf "${_format}" "${count}" "${p##*/}" "${type}" "${p/${DEVTOOL_DIR}\//}"
    done
}
