# # SDL
# cmake --build ./lib/builds/SDL --config Release
# cmake -S ./lib/modules/SDL -B ./lib/builds/SDL 
# 
# # SDF_ttf
# cmake -S ./lib/modules/SDL_ttf -B ./lib/builds/SDL_ttf -DSDL2_LIBRARY="./lib/builds/SDL/build/SDL2.lib" -DSDL2_INCLUDE_DIR="./lib/modules/SDL/include" -DSDL2TTF_VENDORED="ON" -DSDL2TTF_SAMPLES="OFF" -DBUILD_SHARED_LIBS="OFF"
# ./lib/modules/SDL_ttf/external/download.sh
# cmake --build ./lib/builds/SDL_ttf --config Release
#  
# # freetype
# cmake --build ./lib/builds/freetype --config Release
# cmake -S ./lib/modules/freetype -B ./lib/builds/freetype

# GLFW
# cmake -S ./lib/modules/glfw -B ./lib/builds/glfw -DGLFW_BUILD_DOCS="OFF" -DBUILD_SHARED_LIBS="ON"
# cmake --build ./lib/builds/glfw --config Release
mv ./lib/builds/glfw/src/libglfw.so ./zig-out/bin/libglfw.so
