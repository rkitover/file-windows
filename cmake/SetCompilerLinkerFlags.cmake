# From: https://stackoverflow.com/a/41416298/262458
function(REMOVE_DUPES ARG_STR OUTPUT)
  set(ARG_LIST ${ARG_STR})
  separate_arguments(ARG_LIST)
  list(REMOVE_DUPLICATES ARG_LIST)
  string (REGEX REPLACE "([^\\]|^);" "\\1 " _TMP_STR "${ARG_LIST}")
  string (REGEX REPLACE "[\\](.)" "\\1" _TMP_STR "${_TMP_STR}") #fixes escaping
  set (${OUTPUT} "${_TMP_STR}" PARENT_SCOPE)
endfunction()

function(add_compiler_flags)
    foreach(var RELEASE DEBUG RELWITHDEBINFO MINSIZEREL)
        set("CMAKE_CXX_FLAGS_${var}" "" CACHE STRING "MUST BE UNSET" FORCE)
        set("CMAKE_CXX_FLAGS_${var}" "" PARENT_SCOPE)
        set("CMAKE_C_FLAGS_${var}"   "" CACHE STRING "MUST BE UNSET" FORCE)
        set("CMAKE_C_FLAGS_${var}"   "" PARENT_SCOPE)
    endforeach()

    # Set C and CXX flags if not already set.
    foreach(flag ${ARGV})
        foreach(var CMAKE_CXX_FLAGS CMAKE_C_FLAGS)
            # Remove any duplicates first.
            remove_dupes("${${var}}" "${var}")

            string(FIND "${${var}}" "${flag}" found)

            if(found EQUAL -1)
                set("${var}" "${${var}} ${flag}" CACHE STRING "Compiler Flags" FORCE)
                set("${var}" "${${var}} ${flag}" PARENT_SCOPE)
            endif()
        endforeach()
    endforeach()
endfunction()

function(add_linker_flags)
    # Set linker flags if not already set.
    foreach(flag ${ARGV})
        foreach(var EXE SHARED MODULE STATIC)
            set(var "CMAKE_${var}_LINKER_FLAGS")

            # Remove any duplicates first.
            remove_dupes("${${var}}" "${var}")

            string(FIND "${${var}}" "${flag}" found)

            if(found EQUAL -1)
                set("${var}" "${${var}} ${flag}" CACHE STRING "Linker Flags" FORCE)
                set("${var}" "${${var}} ${flag}" PARENT_SCOPE)
            endif()
        endforeach()
    endforeach()
endfunction()
