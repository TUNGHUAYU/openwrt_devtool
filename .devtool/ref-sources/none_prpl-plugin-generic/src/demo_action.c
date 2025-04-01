#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "demo.h"
#include "dm_demo.h"

// conver enum to string table
static const char * const action_names[] = {
    [action_any] = "action_any",
    [action_param_read] = "action_param_read",
    [action_param_write] = "action_param_write",
    [action_param_validate] = "action_param_validate",
    [action_param_describe] = "action_param_describe",
    [action_param_destroy] = "action_param_destroy",
    [action_object_read] = "action_object_read",
    [action_object_write] = "action_object_write",
    [action_object_validate] = "action_object_validate",
    [action_object_list] = "action_object_list",
    [action_object_describe] = "action_object_describe",
    [action_object_tree] = "action_object_tree",
    [action_object_add_inst] = "action_object_add_inst",
    [action_object_del_inst] = "action_object_del_inst",
    [action_object_destroy] = "action_object_destroy",
    [action_object_add_mib] = "action_object_add_mib",
    [action_describe_action] = "action_describe_action"
};


// parameter action handler ( for read and write action only )
// action callback should conduct the original action and customerical behaviour.
amxd_status_t _print_action( 
                    amxd_object_t* object,
                    amxd_param_t* param,
                    amxd_action_t reason,
                    const amxc_var_t* const args,
                    amxc_var_t* const retval,
                    UNUSED void* priv){

    printf("---- Action ----\n");
    
    if( NULL != object->name ){
        printf("object => %s\n", object->name);
    } else {
        printf("object => NULL\n");
    }

    if( NULL != param->name ){
        printf("param  => %s\n", param->name);
    } else {
        printf("object => NULL\n");
    }
    
    if( reason >= 0 ){
        printf("reason => (%d) %s\n", reason, action_names[reason]);
    }
    
    printf("args => \n");
    if(!amxc_var_is_null(args)) {
        amxc_var_dump(args, STDOUT_FILENO);
    }

    // parameter action implemention
    amxd_status_t status = amxd_status_unknown_error;
    switch( reason ){
        case action_param_write:
            when_failed_status(
                amxc_var_convert(
                    &param->value,
                    args,
                    amxc_var_type_of(&param->value)
                ),
                exit,
                status = amxd_status_invalid_value
            );
            break;
        case action_param_read:
            when_failed(
                amxc_var_copy(
                    retval,
                    &param->value
                ),
                exit
            );
            break;
        default:
            printf("no action %s implementation\n", action_names[ reason ]);
    }
    
    // print retval 
    printf("retval => \n");
    if(!amxc_var_is_null(retval)) {
        amxc_var_dump(retval, STDOUT_FILENO);
    }

    fflush(stdout);
    status = amxd_status_ok;

exit:
    return status;
}


amxd_status_t _read_left_time( amxd_object_t* object,
                                amxd_param_t* param,
                                amxd_action_t reason,
                                const amxc_var_t* const args,
                                amxc_var_t* const retval,
                                void* priv) {
    
    uint16_t left_time = amxp_timer_remaining_time(global_timer);
    amxc_var_set(uint16_t, &param->value, left_time);
    return amxd_action_param_read(object,
                                  param,
                                  reason,
                                  args,
                                  retval,
                                  priv);

}

