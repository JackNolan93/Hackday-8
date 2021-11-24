cmake_minimum_required(VERSION 3.10)

project(hackday-8 VERSION 1.0)

include(cmake/update_from_git.cmake)

update_from_git(juce "https://github.com/juce-framework/JUCE" 46ea879739533ca0cdc689b967edfc5390c46ef7)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED true)

add_subdirectory(${juce_SOURCE_DIR})

#set_property(GLOBAL PROPERTY USE_FOLDERS YES)
#set(JUCE_ENABLE_MODULE_SOURCE_GROUPS ON)

juce_add_plugin(hackday-8
        # VERSION ...                               # Set this if the plugin version is different to the project version
        # ICON_BIG ...                              # ICON_* arguments specify a path to an image file to use as an icon for the Standalone
        # ICON_SMALL ...
        # COMPANY_NAME ...                          # Specify the name of the plugin's author
        # IS_SYNTH TRUE/FALSE                       # Is this a synth or an effect?
        # NEEDS_MIDI_INPUT TRUE/FALSE               # Does the plugin need midi input?
        # NEEDS_MIDI_OUTPUT TRUE/FALSE              # Does the plugin need midi output?
        # IS_MIDI_EFFECT TRUE/FALSE                 # Is this plugin a MIDI effect?
        # EDITOR_WANTS_KEYBOARD_FOCUS TRUE/FALSE    # Does the editor need keyboard focus?
        # COPY_PLUGIN_AFTER_BUILD TRUE/FALSE        # Should the plugin be installed to a default location after building?
        PLUGIN_MANUFACTURER_CODE JaLe               # A four-character manufacturer id with at least one upper-case character
        PLUGIN_CODE JaLe                            # A unique four-character plugin id with exactly one upper-case character
        # GarageBand 10.3 requires the first letter to be upper-case, and the remaining letters to be lower-case
        FORMATS AU VST3 Standalone                  # The formats to build. Other valid formats are: AAX Unity VST AU AUv3
        PRODUCT_NAME "Hackday8")        # The name of the final executable, which can differ from the target name

set(PLATFORM_SOURCES "")
if (APPLE)
    list(APPEND PLATFORM_SOURCES Jale_WebBrowserComponent.mm)
endif ()

target_compile_options(hackday-8 PRIVATE -Wall -Wextra -Werror)

target_sources(hackday-8
        PRIVATE
        PluginEditor.cpp
        PluginEditor.h
        PluginProcessor.cpp
        PluginProcessor.h
        JaLe_WebBrowserComponent.h
        ${PLATFORM_SOURCES})

target_link_libraries(hackday-8
        PRIVATE
        juce::juce_core
        juce::juce_audio_utils
        juce::juce_gui_basics
        PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_warning_flags
        juce::juce_recommended_lto_flags)

