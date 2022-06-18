cmake_minimum_required(VERSION 3.15)

project(file)

include(cmake/SetCompilerLinkerFlags.cmake)

# Link MSVC runtime statically.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

add_definitions(-D__STDC_LIMIT_MACROS -DWIN32 -D_FILE_OFFSET_BITS=64)

# Enable max opt flags and LTO for non-debug builds.
if(CMAKE_BUILD_TYPE STREQUAL Release)
  add_compiler_flags(/fp:fast /Oi /O2 /Ob3 /GL)
  add_linker_flags(/LTCG)
endif()

function(cat IN_FILE OUT_FILE)
  file(READ ${IN_FILE} CONTENTS)
  file(APPEND ${OUT_FILE} "${CONTENTS}")
endfunction()

set(FILE_VERSION 5.42)

configure_file(
  "file-version.h.in"
  "${CMAKE_BINARY_DIR}/file-version.h"
  @ONLY
)

set(WIN_COMPAT_SOURCES 
  file/src/asctime_r.c
  file/src/asprintf.c
  file/src/ctime_r.c
  file/src/dprintf.c
  file/src/getline.c
  file/src/gmtime_r.c
  file/src/localtime_r.c
  file/src/pread.c
  file/src/strcasestr.c
  file/src/strlcat.c
  file/src/strlcpy.c
  file/src/vasprintf.c
  file/src/fmtcheck.c
  win-headers/magic.def
)

set(LIBMAGIC_SOURCE_FILES
  ${WIN_COMPAT_SOURCES}
  file/src/apprentice.c
  file/src/apptype.c
  file/src/ascmagic.c
  file/src/buffer.c
  file/src/cdf.c
  file/src/cdf_time.c
  file/src/compress.c
  file/src/der.c
  file/src/encoding.c
  file/src/fsmagic.c
  file/src/funcs.c
  file/src/is_json.c
  file/src/is_tar.c
  ${CMAKE_CURRENT_BINARY_DIR}/magic.c
  file/src/print.c
  file/src/readcdf.c
  ${CMAKE_CURRENT_BINARY_DIR}/readelf.c
  file/src/softmagic.c
  file/src/is_csv.c
)

# Replace the version in the magic.h.in and write it to magic.h
file(READ file/src/magic.h.in MAGIC_H_CONTENT)
string(REPLACE "." "" FILE_VERSION_WITHOUT_DOT "${FILE_VERSION}")
string(REPLACE "X.YY" ${FILE_VERSION_WITHOUT_DOT} MAGIC_H_CONTENT_NEW "${MAGIC_H_CONTENT}")
file(WRITE file/src/magic.h "${MAGIC_H_CONTENT_NEW}")

file(READ file/src/readelf.c READELF_C_CONTENT)
string(CONCAT READELF_C_CONTENT_NEW "#include <dirent.h>\n" "${READELF_C_CONTENT}")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/readelf.c "${READELF_C_CONTENT_NEW}")

file(READ file/src/magic.c MAGIC_C_CONTENT)
string(CONCAT MAGIC_C_CONTENT_NEW "#include <dirent.h>\n" "${MAGIC_C_CONTENT}")
file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/magic.c "${MAGIC_C_CONTENT_NEW}")

file(READ file/src/file.h FILE_H_CONTENT)
string(CONCAT FILE_H_CONTENT_NEW "#ifdef WIN32\n#include <unistd.h>\n#include <dirent.h>\n#undef S_IFLNK\n#undef S_IFSOCK\n#endif\n" "${FILE_H_CONTENT}")
file(WRITE file/src/file.h "${FILE_H_CONTENT_NEW}")

add_library(libmagicstatic STATIC ${LIBMAGIC_SOURCE_FILES})

target_include_directories(libmagicstatic PRIVATE ${CMAKE_SOURCE_DIR})
target_compile_definitions(libmagicstatic PRIVATE -DMAGIC_RESOURCE)

target_include_directories(libmagicstatic PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/win-headers pcre2/src file/src dirent/include getopt zlib-ng ${CMAKE_BINARY_DIR}/zlib-ng lzma/src/liblzma/api bzip2)
target_compile_definitions(libmagicstatic PUBLIC -DHAVE_CONFIG_H -DVERSION="${FILE_VERSION}" -DWIN32_LEAN_AND_MEAN -DWIN32 -DPCRE2_STATIC -DZLIBSUPPORT -DHAVE_ZLIB_H -DXZLIBSUPPORT -DHAVE_LZMA_H -DLZMA_API_STATIC -DHAVE_BZLIB_H -DBZLIBSUPPORT -DHAVE_FORK=0 -Dpipe=sizeof -Dfcntl=sizeof -DF_SETFD=0)

add_library(libmagic SHARED $<TARGET_OBJECTS:libmagicstatic>) 

set(LIBMAGIC_LIBS pcre2-posix shlwapi liblzma zlibstatic libbz2)

target_link_libraries(libmagic ${LIBMAGIC_LIBS})

set_property(TARGET libmagicstatic PROPERTY ARCHIVE_OUTPUT_NAME libmagic)
# Fix conflict with dll import lib.
set_property(TARGET libmagic PROPERTY IMPORT_PREFIX imp)

add_subdirectory(pcre2)

set(BUILD_SHARED_LIBS OFF)
add_subdirectory(lzma)

set(ZLIB_COMPAT ON)
add_subdirectory(zlib-ng)

set(LIBBZ2_SOURCES
  bzip2/blocksort.c
  bzip2/huffman.c
  bzip2/crctable.c
  bzip2/randtable.c
  bzip2/compress.c
  bzip2/decompress.c
  bzip2/bzlib.c
)

add_library(libbz2 STATIC ${LIBBZ2_SOURCES})

target_compile_definitions(libbz2 PUBLIC -DWIN32 -D_FILE_OFFSET_BITS=64)

# copy /pcre2posix.h to regex.h so it can be used as posix regex libary
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/pcre2/src/pcre2posix.h ${CMAKE_CURRENT_SOURCE_DIR}/pcre2/src/regex.h COPYONLY)

add_executable(file file/src/file.c file.rc)

target_include_directories(file PRIVATE "${CMAKE_BINARY_DIR}")
target_link_libraries(file libmagicstatic ${LIBMAGIC_LIBS})

add_executable(file_test file/tests/test.c)

target_link_libraries(file_test libmagicstatic ${LIBMAGIC_LIBS})

# Cleanup changes to submodules post-build.
foreach(submodule file pcre2)
    add_custom_command(
        TARGET file POST_BUILD
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/${submodule}
        COMMAND git reset --hard HEAD
        COMMAND git clean -dxf
    )
endforeach()

# this tests all because of time-zone or crlf errors
set(DISABLED_TESTS 
  gedcom
  fit-map-data
  regex-eol
  )

enable_testing()

file(GLOB TESTFILES "file/tests/*.testfile")
foreach(TEST_FILE ${TESTFILES})
  # extract testname from path and generate command
  string(REGEX MATCH  "(.*)\.testfile" TESTPATH ${TEST_FILE})
  set(TESTPATH ${CMAKE_MATCH_1})
  string(REGEX MATCH  "([a-zA-Z0-9_]|-|\\.)+$" TESTNAME ${TESTPATH})
  if(NOT ${TESTNAME} IN_LIST DISABLED_TESTS)
      add_test(NAME ${TESTNAME} COMMAND ${CMAKE_CURRENT_BINARY_DIR}/file_test ${TEST_FILE} ${TESTPATH}.result)
  endif()
endforeach()


# Following is the compilation of the magic file
set(MAGIC_FRAGMENT_DIR file/magic/Magdir)
file(GLOB MAGIC_FRAGMENTS ${MAGIC_FRAGMENT_DIR}/*)

# Prepare a temporary file to "cat" to:
file(WRITE magic.in "")

# Call the "cat" function for each input file
foreach(MAGIC_FRAGMENT ${MAGIC_FRAGMENTS})
  cat(${MAGIC_FRAGMENT} magic.in)
endforeach()

# Copy the temporary file to the final location
configure_file(magic.in magic COPYONLY)


add_custom_command(OUTPUT magic.mgc
  COMMAND file -C -m magic
  DEPENDS file
  COMMENT "Compiling magic file"
)

add_custom_target(magic_mgc ALL DEPENDS magic.mgc)
