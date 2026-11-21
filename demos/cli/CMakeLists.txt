cmake_minimum_required(VERSION 3.22)
project(MediaVisionCli LANGUAGES C CXX)

# Point CMAKE_PREFIX_PATH at a prebuilt SDK's shared or static directory.
find_package(MediaVisionSDK CONFIG REQUIRED)
add_executable(mvs_demo_cli main.cpp)
target_link_libraries(mvs_demo_cli PRIVATE MediaVision::SDK)
target_compile_features(mvs_demo_cli PRIVATE cxx_std_17)

get_target_property(sdk_type MediaVision::SDK TYPE)
if(sdk_type STREQUAL "SHARED_LIBRARY")
  if(APPLE)
    set_target_properties(mvs_demo_cli PROPERTIES
      BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "@loader_path")
  elseif(UNIX)
    set_target_properties(mvs_demo_cli PROPERTIES
      BUILD_WITH_INSTALL_RPATH TRUE INSTALL_RPATH "$ORIGIN")
  endif()
  add_custom_command(TARGET mvs_demo_cli POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
      "$<TARGET_FILE:MediaVision::SDK>" "$<TARGET_FILE_DIR:mvs_demo_cli>")
endif()
