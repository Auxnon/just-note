# This file controls Flutter-level build steps. It should not be edited.
cmake_minimum_required(VERSION 3.14)

set(EPHEMERAL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ephemeral")

# Configuration provided via flutter tool.
include(${EPHEMERAL_DIR}/generated_config.cmake)

# TODO: Move the rest of this into files in ephemeral. See
# https://github.com/flutter/flutter/issues/57146.
set(WRAPPER_ROOT "${EPHEMERAL_DIR}/cpp_client_wrapper")

# Set fallback configurations for older versions of the flutter tool.
if(NOT DEFINED FLUTTER_TARGET_PLATFORM)
  set(FLUTTER_TARGET_PLATFORM "windows-x64")
endif()

# === Flutter Library ===
set(FLUTTER_LIBRARY "${EPHEMERAL_DIR}/flutter_windows.dll")

# Published to parent scope for install step.
set(FLUTTER_LIBRARY ${FLUTTER_LIBRARY} PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${EPHEMERAL_DIR}/icudtl.dat" PARENT_SCOPE)
set(FLUTTER_ENGINE_DLL "${EPHEMERAL_DIR}/flutter_engine.dll" PARENT_SCOPE)
set(FLUTTER_ASSET_DIR "${EPHEMERAL_DIR}/flutter_assets" PARENT_SCOPE)

# === Wrapper sources ===
list(APPEND CPP_WRAPPER_SOURCES_CORE
  "core_implementations.cc"
  "flutter_view_controller.cc"
  "plugin_registrar.cc"
  "plugin_registry.cc"
)
list(TRANSFORM CPP_WRAPPER_SOURCES_CORE PREPEND "${WRAPPER_ROOT}/")

list(APPEND CPP_WRAPPER_SOURCES_PLUGIN
  "flutter_plugin_registrar.cc"
)
list(TRANSFORM CPP_WRAPPER_SOURCES_PLUGIN PREPEND "${WRAPPER_ROOT}/")

list(APPEND CPP_WRAPPER_SOURCES_APP
  "flutter_engine.cc"
  "flutter_view_controller.cc"
)
list(TRANSFORM CPP_WRAPPER_SOURCES_APP PREPEND "${WRAPPER_ROOT}/")

# === Flutter tool backend ===
# _phony_ is a non-existent file to force this target to always be rebuilt.
set(PHONY_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/_phony_")
set_source_files_properties("${PHONY_OUTPUT}" PROPERTIES SYMBOLIC TRUE)
add_custom_command(
  OUTPUT ${FLUTTER_LIBRARY} ${FLUTTER_ICU_DATA_FILE}
    ${CPP_WRAPPER_SOURCES_CORE} ${CPP_WRAPPER_SOURCES_PLUGIN}
    ${CPP_WRAPPER_SOURCES_APP}
    ${PHONY_OUTPUT}
  COMMAND ${CMAKE_COMMAND} -E env
    FLUTTER_ROOT=${FLUTTER_ROOT}
    FLUTTER_TARGET_PLATFORM=${FLUTTER_TARGET_PLATFORM}
    ${FLUTTER_TOOL_ENVIRONMENT}
    "${FLUTTER_ROOT}/packages/flutter_tools/bin/tool_backend.bat"
      windows-x64 $<CONFIG>
  VERBATIM
)
add_custom_target(flutter_assemble DEPENDS
  "${FLUTTER_LIBRARY}"
  "${FLUTTER_ICU_DATA_FILE}"
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_PLUGIN}
  ${CPP_WRAPPER_SOURCES_APP}
)

# === Flutter library target ===
# All of these sources will be compiled into a static library that is linked
# into the application.
add_library(flutter STATIC
  ${CPP_WRAPPER_SOURCES_CORE}
  ${CPP_WRAPPER_SOURCES_PLUGIN}
  ${CPP_WRAPPER_SOURCES_APP}
)
apply_standard_settings(flutter)
set_target_properties(flutter PROPERTIES
  STATIC_LIBRARY_FLAGS "/DEF:${EPHEMERAL_DIR}/flutter_engine.def"
)
target_compile_features(flutter PUBLIC cxx_std_17)
target_include_directories(flutter PUBLIC
  "${WRAPPER_ROOT}/include"
  "${EPHEMERAL_DIR}"
)
target_link_libraries(flutter PUBLIC "${FLUTTER_LIBRARY}.lib")

# === Wrapper plugin library summary target ===
add_library(flutter_wrapper_plugin INTERFACE)
target_link_libraries(flutter_wrapper_plugin INTERFACE flutter)
target_include_directories(flutter_wrapper_plugin INTERFACE
  "${WRAPPER_ROOT}/include"
)

# === Wrapper app library summary target ===
add_library(flutter_wrapper_app INTERFACE)
target_link_libraries(flutter_wrapper_app INTERFACE flutter)
target_include_directories(flutter_wrapper_app INTERFACE
  "${WRAPPER_ROOT}/include"
)
