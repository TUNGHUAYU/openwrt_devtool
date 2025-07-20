# openwrt-devtool

> author: Terry Yu
>
> version: v2.1.x

## Usage

``` bash
    # List all packages in devtool workspace
    $ bash devtool.sh list

    # New package
    # Type 1: New package from local sample
    $ bash devtool.sh add <pkg-name> 
    # Type 2: New package from remote git repository ( only http url allowed )
    $ bash devtool.sh add <pkg-name> <git-repo-http-url> 

    # Modify existed package 
    $ bash devtool.sh modify [<search-pattern>]

    # Abort the developing package 
    $ bash devtool.sh abort ${OPENWRT_DIR} ${PKG_NAME} 
```


