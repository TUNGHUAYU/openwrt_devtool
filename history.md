History

v2.1.0:

Add new feature for new action.

- Feature
    - action
        - new : Support reference source from remote git repository ( only support `http` url ) 

v2.0.0:

This major version changed architecture for expandable, flexiable, and modulization.
Its change a lot of place including previous infrastructure.  
Therefore, it is **NOT** backward compability.

- Improve
    - architecture
        - .devtool/: Gather devtool related files and folders.
            - scripts/ : Gather shell scripts. 
            - config/  : Gather configuration files.
            - template/: Gather makefile templates.
    - action
        - new    : Support reference Makefiles 
        - new    : Support reference Package Sources.
        - new    : Provide TUI for reference Makefile selection.
        - new    : Provide TUI for reference Package source selection.
        - modify : Provide TUI for openwrt package selection. <br>
                    (searching path: ${OPENWRT_DIR}/package/feed/)
        - abort  : Provide double check mechanism that avoid accidentally deleted.
        
---

v1.3.0:
- Improve
    - feature
        - list  : List all developed packages with relative path ( based on workspace )
        - modify: Copy whole package folder instead of Makefile only. 
                  It can include essential files and folders ( e.g. Config.in, files/, ... )

v1.2.0:
- Add
    - feature
        - list : List all developed packages
        - abort: Abort the specified developed package

v1.1.0:
- Improve
    - feature
        - help  : Add input argument illustration
        - \*modify: Move the package openwrt-Makefile into workspace/PACKAGES/../\<pkg\>/Makefile 

v1.0.0:
- Add
    - feature
        - new:    new package ( prpl plugin sample package )
        - modify: new existed package

**notation**: '\*' represents the change does NOT support backward compability.
