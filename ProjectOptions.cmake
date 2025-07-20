include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(vigilant_spork_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(vigilant_spork_setup_options)
  option(vigilant_spork_ENABLE_HARDENING "Enable hardening" ON)
  option(vigilant_spork_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    vigilant_spork_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    vigilant_spork_ENABLE_HARDENING
    OFF)

  vigilant_spork_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR vigilant_spork_PACKAGING_MAINTAINER_MODE)
    option(vigilant_spork_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(vigilant_spork_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(vigilant_spork_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(vigilant_spork_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(vigilant_spork_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(vigilant_spork_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(vigilant_spork_ENABLE_PCH "Enable precompiled headers" OFF)
    option(vigilant_spork_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(vigilant_spork_ENABLE_IPO "Enable IPO/LTO" ON)
    option(vigilant_spork_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(vigilant_spork_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(vigilant_spork_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(vigilant_spork_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(vigilant_spork_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(vigilant_spork_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(vigilant_spork_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(vigilant_spork_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(vigilant_spork_ENABLE_PCH "Enable precompiled headers" OFF)
    option(vigilant_spork_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      vigilant_spork_ENABLE_IPO
      vigilant_spork_WARNINGS_AS_ERRORS
      vigilant_spork_ENABLE_USER_LINKER
      vigilant_spork_ENABLE_SANITIZER_ADDRESS
      vigilant_spork_ENABLE_SANITIZER_LEAK
      vigilant_spork_ENABLE_SANITIZER_UNDEFINED
      vigilant_spork_ENABLE_SANITIZER_THREAD
      vigilant_spork_ENABLE_SANITIZER_MEMORY
      vigilant_spork_ENABLE_UNITY_BUILD
      vigilant_spork_ENABLE_CLANG_TIDY
      vigilant_spork_ENABLE_CPPCHECK
      vigilant_spork_ENABLE_COVERAGE
      vigilant_spork_ENABLE_PCH
      vigilant_spork_ENABLE_CACHE)
  endif()

  vigilant_spork_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (vigilant_spork_ENABLE_SANITIZER_ADDRESS OR vigilant_spork_ENABLE_SANITIZER_THREAD OR vigilant_spork_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(vigilant_spork_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(vigilant_spork_global_options)
  if(vigilant_spork_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    vigilant_spork_enable_ipo()
  endif()

  vigilant_spork_supports_sanitizers()

  if(vigilant_spork_ENABLE_HARDENING AND vigilant_spork_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR vigilant_spork_ENABLE_SANITIZER_UNDEFINED
       OR vigilant_spork_ENABLE_SANITIZER_ADDRESS
       OR vigilant_spork_ENABLE_SANITIZER_THREAD
       OR vigilant_spork_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${vigilant_spork_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${vigilant_spork_ENABLE_SANITIZER_UNDEFINED}")
    vigilant_spork_enable_hardening(vigilant_spork_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(vigilant_spork_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(vigilant_spork_warnings INTERFACE)
  add_library(vigilant_spork_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  vigilant_spork_set_project_warnings(
    vigilant_spork_warnings
    ${vigilant_spork_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(vigilant_spork_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    vigilant_spork_configure_linker(vigilant_spork_options)
  endif()

  include(cmake/Sanitizers.cmake)
  vigilant_spork_enable_sanitizers(
    vigilant_spork_options
    ${vigilant_spork_ENABLE_SANITIZER_ADDRESS}
    ${vigilant_spork_ENABLE_SANITIZER_LEAK}
    ${vigilant_spork_ENABLE_SANITIZER_UNDEFINED}
    ${vigilant_spork_ENABLE_SANITIZER_THREAD}
    ${vigilant_spork_ENABLE_SANITIZER_MEMORY})

  set_target_properties(vigilant_spork_options PROPERTIES UNITY_BUILD ${vigilant_spork_ENABLE_UNITY_BUILD})

  if(vigilant_spork_ENABLE_PCH)
    target_precompile_headers(
      vigilant_spork_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(vigilant_spork_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    vigilant_spork_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(vigilant_spork_ENABLE_CLANG_TIDY)
    vigilant_spork_enable_clang_tidy(vigilant_spork_options ${vigilant_spork_WARNINGS_AS_ERRORS})
  endif()

  if(vigilant_spork_ENABLE_CPPCHECK)
    vigilant_spork_enable_cppcheck(${vigilant_spork_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(vigilant_spork_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    vigilant_spork_enable_coverage(vigilant_spork_options)
  endif()

  if(vigilant_spork_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(vigilant_spork_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(vigilant_spork_ENABLE_HARDENING AND NOT vigilant_spork_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR vigilant_spork_ENABLE_SANITIZER_UNDEFINED
       OR vigilant_spork_ENABLE_SANITIZER_ADDRESS
       OR vigilant_spork_ENABLE_SANITIZER_THREAD
       OR vigilant_spork_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    vigilant_spork_enable_hardening(vigilant_spork_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
