#if !defined(__DEMO_H__)
#define __DEMO_H__

#ifdef __cplusplus
extern "C"
{
#endif

#include <amxc/amxc_macros.h>
#include <amxc/amxc.h>

#include <amxp/amxp.h>

#include <amxd/amxd_dm.h>
#include <amxd/amxd_object.h>
#include <amxd/amxd_object_event.h>
#include <amxd/amxd_transaction.h>
#include <amxd/amxd_action.h>

#include <amxo/amxo.h>
#include <amxo/amxo_save.h>

#include <amxs/amxs.h>

typedef struct _demo_app {
    amxd_dm_t* dm;
    amxo_parser_t* parser;
} demo_app_t;



// entry-point ( following prpl entry-point prototype )
int _demo_main(
    int reason,
    amxd_dm_t* dm,
    amxo_parser_t* parser
);

// function to get amxd_dm_t or amxo_parser_t object
amxd_dm_t* PRIVATE demo_get_dm(void);
amxo_parser_t* PRIVATE demo_get_parser(void);

#ifdef __cplusplus
}
#endif

#endif // __DEMO_H__
