cmake_minimum_required(VERSION 3.22.1)
project(labelprint)

# Thermal label rendering for the shelf-edge printer (dithering is too slow on the JVM).
add_library(labelprint SHARED labelprint.cpp)
find_library(log-lib log)
target_link_libraries(labelprint ${log-lib})
