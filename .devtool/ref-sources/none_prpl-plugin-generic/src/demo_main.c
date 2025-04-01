#include <stdio.h>
#include "demo.h"

static demo_app_t app;

amxd_dm_t* PRIVATE demo_get_dm(void) {
    return app.dm;
}

amxo_parser_t* PRIVATE demo_get_parser(void) {
    return app.parser;
}

int _demo_main(
    int reason,
    amxd_dm_t* dm,
    amxo_parser_t* parser) {

    switch(reason) {
    case 0:     // START
        app.dm = dm;
        app.parser = parser;
        break;
    case 1:     // STOP
        app.dm = NULL;
        app.parser = NULL;
        break;
    }

    return 0;
}
