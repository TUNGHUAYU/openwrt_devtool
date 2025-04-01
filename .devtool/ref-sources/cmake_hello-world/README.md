# hello_world

> Practice to create a simple C project and setup the CMakeList.txt file.

## structure

~~~
/home/terry/Documents/github/hello_world
├── build
├── CMakeLists.txt
├── inc
│   └── foo.h
├── lib
├── README.md
└── src
    ├── foo.c
    └── main.c

4 directories, 5 files
~~~

## implement commands

1. mkdir build
2. cd build
3. cmake ../
4. make
5. cmake --install . --prefix "/path/to/install/folder"


## related reference
1. how does executable file search neccessary shared library? ( below website explains all details )
https://medium.com/fcamels-notes/linux-%E5%9F%B7%E8%A1%8C%E6%99%82%E5%B0%8B%E6%89%BE-symbol-%E7%9A%84%E6%B5%81%E7%A8%8B%E4%BB%A5%E5%8F%8A-shared-library-%E7%9B%B8%E9%97%9C%E7%9F%A5%E8%AD%98-b0cf1e19cbf3
