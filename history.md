History
please see the [confluence
page](https://arc-conf.arcadyan.com.tw/pages/viewpage.action?spaceKey=TERRYYU&title=Orange+-+openwrt-devtool) to know
the details

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

**notation**: '\*' represents the change does NOT support backward incompability.
