# A CMake project using an installed FIGURE (scripts/install.sh): find_package finds lib/cmake/figure-<tag>/, the one
# whose compiler is this project's Fortran compiler, and figure::figure brings its modules and its link line.
#   cmake -S scripts/cmake_consumer -B build/cmake_consumer -DCMAKE_PREFIX_PATH=<prefix> -DCMAKE_Fortran_COMPILER=<fc>
#   cmake --build build/cmake_consumer && build/cmake_consumer/figure_cmake_consumer
cmake_minimum_required(VERSION 3.24)
project(figure_cmake_consumer LANGUAGES Fortran)
find_package(figure 0.6 CONFIG REQUIRED)
message(STATUS "FIGURE ${figure_VERSION} for ${figure_COMPILER}, from ${figure_DIR}")
add_executable(figure_cmake_consumer figure_cmake_consumer.F90)
target_link_libraries(figure_cmake_consumer PRIVATE figure::figure)
