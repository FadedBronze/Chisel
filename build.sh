# SDF_ttf
cmake -S ./lib/modules/SDL_ttf -B ./lib/builds/SDL_ttf -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE="./build" -DSDL2_LIBRARY="./lib/builds/SDL/build/SDL2.lib" -DSDL2_INCLUDE_DIR="./lib/modules/SDL/include" -DSDL2TTF_VENDORED="ON" -DSDL2TTF_SAMPLES="OFF" -DBUILD_SHARED_LIBS="OFF"
./lib/modules/SDL_ttf/external/download.sh
cmake --build ./lib/builds/SDL_ttf --config Release

# SDL
cmake --build ./lib/builds/SDL --config Release
cmake -S ./lib/modules/SDL -B ./lib/builds/SDL -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE="./build"
 
# freetype
cmake --build ./lib/builds/freetype --config Release
cmake -S ./lib/modules/freetype -B ./lib/builds/freetype -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE="./build"

# GLFW
cmake -S ./lib/modules/glfw -B ./lib/builds/glfw -DCMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_LIBRARY_OUTPUT_DIRECTORY_RELEASE="./build" -DCMAKE_ARCHIVE_OUTPUT_DIRECTORY_RELEASE="./build" -DGLFW_BUILD_DOCS="OFF"
cmake --build ./lib/builds/glfw --config Release
