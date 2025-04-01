#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "demo.h"
#include "dm_demo.h"

void _print_event( 
    const char* const sig_name, 
    const amxc_var_t* const data, 
    UNUSED void* const priv ) 
{

    printf("---- signal ----\n");
    printf("Signal received - %s\n", sig_name);
    printf("Signal data = \n");
    fflush(stdout);
    if(!amxc_var_is_null(data)) {
        amxc_var_dump(data, STDOUT_FILENO);
    }
}
