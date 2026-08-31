cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Application icon (regenerate with `dart run tool/generate_logo.dart`).
set(APPLICATION_ICON "${CMAKE_CURRENT_SOURCE_DIR}/resources/app_icon.png")
add_definitions(-DAPPLICATION_ICON="${APPLICATION_ICON}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")

# Install the icon alongside the binary.
set(INSTALL_BINDIR "${CMAKE_INSTALL_PREFIX}/bin")
install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${INSTALL_BINDIR}")
install(FILES "${APPLICATION_ICON}" DESTINATION "${INSTALL_BINDIR}")
