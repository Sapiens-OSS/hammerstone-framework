cmake_minimum_required(VERSION 3.23)

set(MOD_ID "hammerstone-framework")

mark_as_advanced(MOD_TYPE) # Should not be changed for c mods as c mods are used for world specific things only.

project(${MOD_ID} C)

set(CMAKE_C_STANDARD 99)

add_library(${MOD_ID} SHARED src/height.c src/biome.c)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/splugins/include)
find_library(SP_LIBRARY SPCommon PATHS ${CMAKE_CURRENT_SOURCE_DIR}/splugins/lib REQUIRED)
mark_as_advanced(SP_LIBRARY)
target_link_libraries(${MOD_ID} ${SP_LIBRARY})

add_custom_command(TARGET ${MOD_ID} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:${MOD_ID}>"
        "${CMAKE_CURRENT_BINARY_DIR}/lib/$<TARGET_FILE_NAME:${MOD_ID}>")

# Generate symlink to the mod's folder in the game's mods folder
set(AUTO_GENERATE_SAPIENS_MOD_SYMLINK OFF CACHE BOOL "When ON attempt to create a symlink to the mod in the sapiens mod directory. Requires special privileges.")

if (AUTO_GENERATE_SAPIENS_MOD_SYMLINK)
    if (WIN32)
        set(_symlink_source "$ENV{APPDATA}\\majicjungle\\sapiens\\mods")
    else ()
        message(STATUS "Auto symlink currently only supported on windows.")
    endif ()
    if (EXISTS ${_symlink_source})
        message(STATUS "Attempting to create a symlink to the mod in the sapiens mod directory.")
        message(STATUS "Creating symlink in ${_symlink_source}")
        if (EXISTS "${_symlink_source}\\${MOD_ID}")
            message(STATUS "Symlink already exists.")
        else ()
            execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink
                    "${CMAKE_CURRENT_BINARY_DIR}/${MOD_ID}/"
                    "${_symlink_source}/${MOD_ID}/"
                    ERROR_VARIABLE _symlink_error)
            if (_symlink_error)
                message(STATUS "Failed to create symlink in ${_symlink_source}:\n" "${_symlink_error}")
            endif ()
        endif ()
    else ()
        message(STATUS "Sapiens mod directory not found.")
    endif ()
endif ()
