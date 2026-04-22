cmake_minimum_required(VERSION 3.10)

# Paddle Lite and OpenCV archives are downloaded/extracted by the Flutter plugin's
# android/build.gradle into android/PaddleLite/ and android/OpenCV/. These paths are
# resolved relative to this CMakeLists.txt (which sits at android/src/main/cpp/).
set(PaddleLite_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../PaddleLite")
include_directories(${PaddleLite_DIR}/cxx/include)

set(OpenCV_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../OpenCV/sdk/native/jni")
find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

aux_source_directory(. SOURCES)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ffast-math -Ofast -Os")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden -fdata-sections -ffunction-sections")
# --no-fatal-warnings: NDK r27's ld.lld flags Paddle Lite v2.10's prebuilt .so for
# non-local _edata/_end/__bss_start symbols. The lib still links and runs; we just
# need to stop the linker from escalating the warning to an error.
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--gc-sections -Wl,-z,nocopyreloc -Wl,--no-fatal-warnings")

add_library(Native SHARED ${SOURCES})

find_library(log-lib log)

add_library(paddle_light_api_shared SHARED IMPORTED)
set_target_properties(
        paddle_light_api_shared
        PROPERTIES IMPORTED_LOCATION
        ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libpaddle_light_api_shared.so)

target_link_libraries(
        Native
        paddle_light_api_shared
        ${OpenCV_LIBS}
        GLESv2
        EGL
        jnigraphics
        ${log-lib})

# Copy required shared libs next to libNative.so so Gradle packages them into the AAR.
add_custom_command(TARGET Native POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
        ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libc++_shared.so
        ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libc++_shared.so)

add_custom_command(TARGET Native POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy
        ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libpaddle_light_api_shared.so
        ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libpaddle_light_api_shared.so)

# HiAI libs are only present for arm64-v8a; wrap in a guard so armeabi-v7a builds don't fail.
if(EXISTS ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libhiai.so)
    add_custom_command(TARGET Native POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libhiai.so
            ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libhiai.so)
    add_custom_command(TARGET Native POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libhiai_ir.so
            ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libhiai_ir.so)
    add_custom_command(TARGET Native POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libhiai_ir_build.so
            ${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/libhiai_ir_build.so)
endif()
