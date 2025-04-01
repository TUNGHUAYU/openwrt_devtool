#if !defined(__DM_DEMO_H__)
#define __DM_DEMO_H__

#ifdef __cplusplus
extern "C"
{
#endif

amxd_status_t _print_action( 
                    amxd_object_t* object,
                    amxd_param_t* param,
                    amxd_action_t reason,
                    const amxc_var_t* const args,
                    amxc_var_t* const retval,
                    UNUSED void* priv);

void _print_event(
    const char* const sig_name,
    const amxc_var_t* const data,
    void* const priv);

amxd_status_t _Bulletin_say(
    amxd_object_t* bulletin_obj,
    UNUSED amxd_function_t* func,
    amxc_var_t* args,
    amxc_var_t* ret);


amxd_status_t _Sync_sync_object(
    amxd_object_t* sync_obj,
    UNUSED amxd_function_t* func,
    amxc_var_t* args,
    amxc_var_t* ret);


extern amxp_timer_t * global_timer;

void timer_cb(
    UNUSED amxp_timer_t *timer,
    UNUSED void *priv);

amxd_status_t _Timer_enable(
    UNUSED amxd_object_t* sync_obj,
    UNUSED amxd_function_t* func,
    UNUSED amxc_var_t* args,
    UNUSED amxc_var_t* ret);

amxd_status_t _Timer_disable(
    UNUSED amxd_object_t* sync_obj,
    UNUSED amxd_function_t* func,
    UNUSED amxc_var_t* args,
    UNUSED amxc_var_t* ret);

amxd_status_t _read_left_time( amxd_object_t* object,
                                amxd_param_t* param,
                                amxd_action_t reason,
                                const amxc_var_t* const args,
                                amxc_var_t* const retval,
                                void* priv);
#ifdef __cplusplus
}
#endif

#endif // __DM_DEMO_H__




