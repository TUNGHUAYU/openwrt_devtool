# openwrt-devtool

> author: Terry Yu ( terry_yu@arcadyan.com.tw )
>
> version: v1.2.0


Please contact with me or leave question in the below confluence page
[Confluence page](https://arc-conf.arcadyan.com.tw/display/TERRYYU/Orange+-+openwrt-devtool)


## Usage

``` bash
    # List all developing packages
    $ bash devtool.sh list

    # New package ( prpl plugin )
    $ bash devtool.sh add ${OPENWRT_DIR} ${PKG_NAME}

    # Modify existed package 
    $ bash devtool.sh modify ${OPENWRT_PKG_DIR}

    # Abort the developing package
    $ bash devtool.sh abort ${OPENWRT_DIR} ${PKG_NAME} 
```


