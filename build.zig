const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .root_source_file = std.Build.LazyPath{
            .cwd_relative = "main.zig",
        },
        .name = "chsl2.0",
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(std.Build.LazyPath{
        .cwd_relative = "lib/",
    });

    exe.addCSourceFile(.{
        .file = std.Build.LazyPath{
            .cwd_relative = "lib/stb_image_write.c",
        },
        .flags = &[_][]const u8{"-std=c99"},
    });

    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("freetype2");
    exe.linkSystemLibrary("SDL2_ttf");
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("GLEW");

    const zm = b.dependency("zm", .{
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zm", zm.module("zm"));

    b.installArtifact(exe);
}
