#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "demo.h"
#include "dm_demo.h"

amxp_timer_t* global_timer = NULL;


static bool add_message(
    amxd_object_t* bulletin_obj,
    amxc_var_t* author,
    amxc_var_t* msg) 
{
    bool retval = false;
    amxd_dm_t* dm = amxd_object_get_dm(bulletin_obj);
    amxd_object_t* post_obj = amxd_object_get_child(bulletin_obj, "Post");

    amxd_trans_t transaction;
    amxd_trans_init(&transaction);
    amxd_trans_set_attr(&transaction, amxd_tattr_change_ro, true);

    amxd_trans_select_object(&transaction, post_obj);
    amxd_trans_add_inst(&transaction, 0, NULL);
    amxd_trans_set_param(&transaction, "Author", author);
    amxd_trans_set_param(&transaction, "Message", msg);
    if(amxd_trans_apply(&transaction, dm) != amxd_status_ok) {
        goto exit;
    }

    retval = true;

exit:
    amxd_trans_clean(&transaction);
    return retval;
}

amxd_status_t _Bulletin_say(
    amxd_object_t* bulletin_obj,
    UNUSED amxd_function_t* func,
    amxc_var_t* args,
    amxc_var_t* ret) 
{
    printf("---- call %s ----\n", __func__);

    amxd_status_t status = amxd_status_unknown_error;
    amxc_var_t* author = GET_ARG(args, "author");
    amxc_var_t* msg = GET_ARG(args, "message");
    char* author_txt = amxc_var_dyncast(cstring_t, author);
    char* msg_txt = amxc_var_dyncast(cstring_t, msg);

    if(!add_message(bulletin_obj, author, msg)) {
       goto exit;
    }

    printf("==> %s posted '%s'\n", author_txt, msg_txt);
    fflush(stdout);
    amxc_var_set(cstring_t, ret, msg_txt);

    status = amxd_status_ok;
    
    exit:
    free(author_txt);
    free(msg_txt);
    return status;
}

amxd_status_t _Sync_sync_object(
    UNUSED amxd_object_t* sync_obj,
    UNUSED amxd_function_t* func,
    UNUSED amxc_var_t* args,
    UNUSED amxc_var_t* ret) 
{

    amxs_sync_ctx_t* ctx = NULL;

    printf("=== call %s ===\n", __func__);
    amxd_status_t amxd_status = amxd_status_unknown_error;
    amxs_status_t amxs_status = amxs_status_ok;



    // host manager - start
     amxs_sync_object_t * obj = NULL;
     amxs_status = amxs_sync_ctx_new(&ctx, "Device.Hosts.", "Demo.Hosts.", AMXS_SYNC_DEFAULT);
     printf("amxs_status: %d\n", amxs_status);
 
     amxs_status |= amxs_sync_object_new_copy(&obj, "Host.", "Host.", AMXS_SYNC_DEFAULT);
     printf("amxs_status: %d\n", amxs_status);
 
     amxs_status |= amxs_sync_object_add_new_copy_param(obj, "HostName", "HostName", AMXS_SYNC_DEFAULT);
     printf("amxs_status: %d\n", amxs_status);
 
     amxs_status |= amxs_sync_ctx_add_object(ctx, obj);
     printf("amxs_status: %d\n", amxs_status);
 
     amxs_status = amxs_sync_ctx_start_sync(ctx);
     printf("amxs_status: %d\n", amxs_status);

    // host manager - end


    amxd_status = amxd_status_ok;

    return amxd_status;
}


void timer_cb(
    UNUSED amxp_timer_t *timer,
    UNUSED void *priv) {
    
    printf("time's up\n");

}

amxd_status_t _Timer_enable(
    UNUSED amxd_object_t* sync_obj,
    UNUSED amxd_function_t* func,
    UNUSED amxc_var_t* args,
    UNUSED amxc_var_t* ret) 
{
    printf("=== call %s ===\n", __func__);

    amxd_status_t amxd_status = amxd_status_unknown_error;
    amxp_timer_state_t state = amxp_timer_off;
    state = amxp_timer_get_state( global_timer );

    switch ( state ){
        case amxp_timer_off:
            printf("amxp_timer_off\n");
            amxp_timer_new(&global_timer, timer_cb, NULL);
            amxp_timer_set_interval(global_timer, 5000);
            amxp_timer_start(global_timer, 10000);
            break;
        case amxp_timer_started:
            printf("amxp_timer_started\n");
            break;
        case amxp_timer_running:
            printf("amxp_timer_running\n");
            printf("timer reseted\n");
            amxp_timer_start(global_timer, 10000);
            break;
        case amxp_timer_expired:
            printf("amxp_timer_expired\n");
            break;
        case amxp_timer_deleted:
            printf("amxp_timer_deleted\n");
            amxp_timer_new(&global_timer, timer_cb, NULL);
            amxp_timer_set_interval(global_timer, 5000);
            amxp_timer_start(global_timer, 10000);
            break;
        default:
            printf("unexpected error!!\n");
            amxp_timer_delete(&global_timer);
            break;
    }
    amxd_status = amxd_status_ok;

    return amxd_status;
}

amxd_status_t _Timer_disable(
    UNUSED amxd_object_t* sync_obj,
    UNUSED amxd_function_t* func,
    UNUSED amxc_var_t* args,
    UNUSED amxc_var_t* ret) 
{
    printf("=== call %s ===\n", __func__);

    amxd_status_t amxd_status = amxd_status_unknown_error;
    amxp_timer_state_t state = amxp_timer_off;
    state = amxp_timer_get_state( global_timer );

    switch ( state ){
        case amxp_timer_started:
        case amxp_timer_running:
            amxp_timer_stop(global_timer);
            break;
        case amxp_timer_off:
        case amxp_timer_expired:
            printf("timer stopped already\n");
            break;
        case amxp_timer_deleted:
            amxp_timer_new(&global_timer, timer_cb, NULL);
            amxp_timer_set_interval(global_timer, 5000);
            break;
        default:
            printf("unexpected error!!\n");
            amxp_timer_delete(&global_timer);
            break;
    }

    amxd_status = amxd_status_ok;

    return amxd_status;
}
