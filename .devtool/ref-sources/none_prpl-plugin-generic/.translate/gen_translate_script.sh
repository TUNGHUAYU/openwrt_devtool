WORK_DIR=$(realpath $0)
WORK_DIR=${WORK_DIR%/*}/..
WORK_DIR=$(realpath $WORK_DIR)


#
function HELP(){
    echo "usage: ${0##*/} <DST_NAME>"
}

#
if [[ $# -ne 1 ]]; then
    HELP
    exit 1
fi

#
DST_NAME=$1
echo ""
echo "WORK_DIR=${WORK_DIR}"
echo "SRC_pattern=\"demo/Demo/DEMO\""
echo "DST_pattern=${DST_NAME}"
echo ""

{
    echo "####"
    echo "# Replace \"demo/Demo/DEMO\" with \"${DST_NAME}\" in file content"
    echo "####"
    echo 
    
    # convert content with ${DST_NAME}
    grep -rni --exclude-dir ".translate" --exclude-dir ".git" --color=never "demo" ${WORK_DIR}  | \
    awk -F":" \
    -v DST_NAME=${DST_NAME} \
    '
    $3 ~ /demo/ {
        printf "# %s\n", $0 
        printf "sed -i \x27%ss/%s/%s/g\x27 %s\n", $2, "demo", DST_NAME, $1
        printf "\n"
    }
    
    $3 ~ /DEMO/ {
        printf "# %s\n", $0 
        printf "sed -i \x27%ss/%s/%s/g\x27 %s\n", $2, "DEMO", toupper(DST_NAME), $1
        printf "\n"
    }
    
    $3 ~ /Demo/ {
        printf "# %s\n", $0 
        printf "sed -i \x27%ss/%s/%s/g\x27 %s\n", $2, "Demo", DST_NAME, $1
        printf "\n"
    }
    ' 
    
    # convert filename to ${DST_NAME}
    echo "###"
    echo "# Replace filename part "demo" with pattern \"${DST_NAME}\""
    echo "###"
    echo

    find ${WORK_DIR} -name "*demo*" -type f  | \
    awk \
    -v DST_NAME=${DST_NAME} \
    '
    BEGIN{
        FS="/"
        OFS="/"
    }
    
    $NF ~ /demo/ {
        before_filepath=$0
        gsub(/demo/, DST_NAME, $NF); OFS="/";
        after_filepath=$0

        printf "mv %s %s\n", before_filepath, after_filepath 
    }   
    '


    #for p in $(find ${WORK_DIR} -name "*demo*")
    #do
    #    rename_p=$( echo $p | sed s/demo/${DST_NAME}/g )
    #    echo "mv $p $rename_p" 
    #    echo ""                
    #done

} > translate.cmd.sh
