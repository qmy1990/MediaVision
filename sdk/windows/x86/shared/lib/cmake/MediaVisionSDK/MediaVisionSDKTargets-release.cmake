#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "MediaVision::SDK" for configuration "Release"
set_property(TARGET MediaVision::SDK APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(MediaVision::SDK PROPERTIES
  IMPORTED_IMPLIB_RELEASE "${_IMPORT_PREFIX}/lib/mvs_sdk.lib"
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/bin/mvs_sdk.dll"
  )

list(APPEND _cmake_import_check_targets MediaVision::SDK )
list(APPEND _cmake_import_check_files_for_MediaVision::SDK "${_IMPORT_PREFIX}/lib/mvs_sdk.lib" "${_IMPORT_PREFIX}/bin/mvs_sdk.dll" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
