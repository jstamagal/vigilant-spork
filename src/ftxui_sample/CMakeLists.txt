add_executable(intro main.cpp)

target_link_libraries(
  intro
  PRIVATE vigilant_spork::vigilant_spork_options
          vigilant_spork::vigilant_spork_warnings)

target_link_system_libraries(
  intro
  PRIVATE
          CLI11::CLI11
          fmt::fmt
          spdlog::spdlog
          lefticus::tools
          ftxui::screen
          ftxui::dom
          ftxui::component)

target_include_directories(intro PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include")
