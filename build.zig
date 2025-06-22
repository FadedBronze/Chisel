const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(std.Build.StandardTargetOptionsArgs{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .root_module = b.createModule(std.Build.Module.CreateOptions{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .name = "chsl2.0",
    });

    const c_source_file_includes = [_][]const u8{
        "lib/stb_image",
        "lib/glad/include",
    };

    const c_source_file_src = [_][]const u8{
        "lib/stb_image/stb_image_write.c",
        "lib/glad/src/glad.c",
    };

    for (0..c_source_file_includes.len) |i| {
        const src = c_source_file_src[i];
        const include = c_source_file_includes[i];

        exe.addCSourceFile(.{
            .file = std.Build.LazyPath{
                .cwd_relative = src,
            },
            .flags = &[_][]const u8{"-std=c99"},
        });
    
        exe.addIncludePath(.{ .cwd_relative = include });
    }

    const zm = b.dependency("zm", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zm", zm.module("zm"));

    const c_deps_repo_names = [_][]const u8{
        "SDL",
        "glfw",
        "freetype",
        "SDL_ttf"
    };

    const c_deps_lib_names = [_][]const u8{
        "SDL2",
        "glfw",
        "freetype",
        "SDL2_ttf"
    };

    for (0..c_deps_lib_names.len) |i| {
        const dep_lib_name = c_deps_lib_names[i];
        const dep_repo_name = c_deps_repo_names[i];

        const dep = b.dependency(dep_repo_name, .{
            .target = target,
            .optimize = optimize,
        });

        const dep_lib = dep.artifact(dep_lib_name);
        exe.root_module.addIncludePath(dep_lib.getEmittedIncludeTree().path(b, dep_lib_name));
        exe.linkLibrary(dep_lib);
    }

    b.installArtifact(exe);
}
