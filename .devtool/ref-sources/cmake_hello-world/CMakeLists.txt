# cmake version should be higher than Version 2.4
cmake_minimum_required(VERSION 2.4)

# set the project name
project(hello)

# add path to header searching list
include_directories(inc)

# library
add_library(foo_static STATIC src/foo.c)
add_library(foo_shared SHARED src/foo.c)

# binary file
add_executable(app_static src/main.c)
target_link_libraries(app_static foo_static)

add_executable(app_shared src/main.c)
target_link_libraries(app_shared foo_shared)

# install 
install(TARGETS app_static DESTINATION bin)
install(TARGETS app_shared DESTINATION bin)
install(TARGETS foo_static DESTINATION lib)
install(TARGETS foo_shared DESTINATION lib)
install(FILES inc/foo.h DESTINATION inc)
install(FILES src/main.c DESTINATION src)
