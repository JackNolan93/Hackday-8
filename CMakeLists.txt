cmake_minimum_required(VERSION 3.10)

project(hackday-8 VERSION 1.0)

include(cmake/update_from_git.cmake)

update_from_git(juce "https://github.com/juce-framework/JUCE" 46ea879739533ca0cdc689b967edfc5390c46ef7)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED true)

add_subdirectory(${juce_SOURCE_DIR})

#set_property(GLOBAL PROPERTY USE_FOLDERS YES)
#set(JUCE_ENABLE_MODULE_SOURCE_GROUPS ON)

juce_add_console_app(hackday-8 PRODUCT_NAME "DFT Impl")

target_compile_options(hackday-8 PRIVATE -Wall -Wextra -Werror)

target_sources(hackday-8
        PRIVATE
        main.cpp)

target_link_libraries(hackday-8
        PRIVATE
        juce::juce_core
        PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_warning_flags)

