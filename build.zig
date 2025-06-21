const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(std.Build.StandardTargetOptionsArgs{
        .default_target = .{
            .abi = if (builtin.os.tag == .windows) .msvc else .gnu,
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .root_source_file = std.Build.LazyPath{
            .cwd_relative = "main.zig",
        },
        .name = "chsl2.0",
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = "lib/modules/SDL/include" });
    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = "lib/" });
    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = "lib/modules/SDL_ttf" });
    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = "lib/glad/include" });
    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = "lib/modules/freetype/include" });
    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = "lib/modules/freetype/include" });
    exe.addIncludePath(std.Build.LazyPath{ .cwd_relative = "lib/modules/glfw/include" });
    
    // link C
    exe.linkSystemLibrary("c");

    // link Platform APIs
    switch (builtin.os.tag) {
        .windows => {
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("shell32");
            exe.linkSystemLibrary("ole32");
            exe.linkSystemLibrary("oleaut32");
            exe.linkSystemLibrary("advapi32");
            exe.linkSystemLibrary("comdlg32");
            exe.linkSystemLibrary("setupapi");
            exe.linkSystemLibrary("winmm");
            exe.linkSystemLibrary("imm32");
            exe.linkSystemLibrary("version");
            exe.linkSystemLibrary("opengl32");
            exe.linkSystemLibrary("uuid");
            exe.linkSystemLibrary("dinput8");
            exe.linkSystemLibrary("dxguid");
        },
        .linux => {
            exe.linkSystemLibrary("X11");
            exe.linkSystemLibrary("Xrandr");
            exe.linkSystemLibrary("Xi");
            exe.linkSystemLibrary("GL");
            exe.linkSystemLibrary("dl");
            exe.linkSystemLibrary("pthread");
            exe.linkSystemLibrary("m");
        },
        else => return error.UnsupportedPlatform
    }

    exe.addCSourceFile(.{ 
        .file = std.Build.LazyPath{ .cwd_relative = "lib/stb_image_write.c", }, 
        .flags = &[_][]const u8{"-std=c99"},
    });

    exe.addCSourceFile(.{ 
        .file = std.Build.LazyPath{ .cwd_relative = "lib/glad/src/glad.c", }, 
        .flags = &[_][]const u8{"-std=c99"}, 
    });

    exe.addObjectFile(.{ .cwd_relative = "lib/builds/SDL_ttf/build/SDL2_ttf.lib" });
    exe.addObjectFile(.{ .cwd_relative = "lib/builds/freetype/build/freetype.lib" });
    exe.addObjectFile(.{ .cwd_relative = "lib/builds/SDL/build/SDL2-static.lib" });
    exe.addObjectFile(.{ .cwd_relative = "lib/builds/glfw/src/build/glfw3.lib" });

    const zm = b.dependency("zm", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zm", zm.module("zm"));

    b.installArtifact(exe);
}
