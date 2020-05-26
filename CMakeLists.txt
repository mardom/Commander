# the necessary minimum to set-up cmake
cmake_minimum_required(VERSION 3.17 FATAL_ERROR)
project(CommanderSuperbuild
	DESCRIPTION "Complete installer for Commander 3"
	VERSION 1.0.0	
	LANGUAGES Fortran CXX C
	)

# ensuring that we do out-of-source build
if(${PROJECT_SOURCE_DIR} STREQUAL ${PROJECT_BINARY_DIR})
    message(FATAL_ERROR "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there.")
endif()

# including native cmake commands 
include(CMakePrintHelpers)
include(CMakeDependentOption)
# enables content population at configure time
include(FetchContent)
# including external project routines to enable superbuild pattern
include(ExternalProject)
# verify that Fortran and CXX compilers can properly talk to each other
include(FortranCInterface)
FortranCInterface_VERIFY(CXX)
# check if given fortran source compiles
include(CheckFortranSourceCompiles)
# the -fPIC flag
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
# the -flto

# use this to write your own find_package
find_package(PkgConfig)
# We will be using Git to download some dependencies, so we need to check if git available
include(FindGit)
find_package(Git REQUIRED)

# adding project modules dir (with .cmake extension)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
# including cmake modules
include(project_instructions)
# adding commander3 source files
add_subdirectory(commander3)