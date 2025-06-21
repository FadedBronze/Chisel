const std = @import("std");

const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GL/gl.h");
    @cInclude("GLFW/glfw3.h");
});

const Primatives = @import("Primatives.zig");
const utils = @import("utils.zig");
const InputEventInfo = utils.InputEventInfo;
const Bounds = utils.Bounds;
const Extents = utils.Extents;
const SDFFontAtlas = @import("SDFFontAtlas.zig");

const OpenGL = @This();
const Renderer = @import("./Rendering.zig");

const zm = @import("zm");

renderer: Renderer,
atlas: SDFFontAtlas,
window: *c.GLFWwindow,
screen_size: Extents,
mouse_position: [2]f32,
scroll_offset: [2]f32,
mouse_down: bool,

pub fn cursorPositionCallback(window: ?*c.GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void {
    const opengl: *OpenGL = @alignCast(@ptrCast(c.glfwGetWindowUserPointer(window)));
    opengl.mouse_position = [2]f32{ @floatCast(xpos), @floatCast(ypos) };
}

pub fn mouseButtonCallback(window: ?*c.GLFWwindow, button: c_int, action: c_int, _: c_int) callconv(.C) void {
    const opengl: *OpenGL = @alignCast(@ptrCast(c.glfwGetWindowUserPointer(window)));

    if (button == c.GLFW_MOUSE_BUTTON_LEFT) {
        opengl.mouse_down = action == c.GLFW_PRESS;
    }
}

pub fn scrollCallback(window: ?*c.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void {
    const opengl: *OpenGL = @alignCast(@ptrCast(c.glfwGetWindowUserPointer(window)));
    opengl.scroll_offset = [2]f32{ @floatCast(xoffset), @floatCast(yoffset) };
}

pub fn frameBufferSizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    c.glViewport(0, 0, width, height);

    const opengl: *OpenGL = @alignCast(@ptrCast(c.glfwGetWindowUserPointer(window)));
    opengl.screen_size = Extents{
        .width = @floatFromInt(width),
        .height = @floatFromInt(height),
    };
}

fn debugCallback(source: c.GLenum, typename: c.GLenum, id: c.GLuint, severity: c.GLenum, length: c.GLsizei, message: [*c]const u8, userParam: ?*const anyopaque) callconv(.C) void {
    _ = userParam;
    _ = length;
    _ = id;
    std.debug.print("OpenGL Debug Message:\nSource: {}\nType: {}\nSeverity: {}\nMessage: {s}\n", .{ source, typename, severity, message });
}

pub fn init(self: *OpenGL, width: f32, height: f32) !void {
    if (c.glfwInit() == c.GLFW_FALSE) {
        return error.GFLWInitFailed;
    }

    const width_int = @as(i32, @intFromFloat(width));
    const height_int = @as(i32, @intFromFloat(height));

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    const window = c.glfwCreateWindow(width_int, height_int, "Hello World", null, null);

    if (window == null) {
        c.glfwTerminate();
        return error.GLFWWindowInitFailed;
    }

    c.glfwMakeContextCurrent(window);
    
    const version = c.gladLoadGL();

    if (version == 0) {
        return error.GLADInitFailed;
    }

    c.glViewport(0, 0, width_int, height_int);

    c.glfwSetWindowUserPointer(window, self);

    _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallback);

    _ = c.glfwSetCursorPosCallback(window, cursorPositionCallback);

    _ = c.glfwSetFramebufferSizeCallback(window, frameBufferSizeCallback);

    _ = c.glfwSetScrollCallback(window, scrollCallback);
    
    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    c.glEnable(c.GL_DEBUG_OUTPUT);
    c.glad_glDebugMessageCallback.?(debugCallback, null);

    self.* = OpenGL{
        .screen_size = Extents{ .height = height, .width = width },
        .window = window.?,
        .mouse_down = false,
        .mouse_position = .{ 0, 0 },
        .scroll_offset = .{ 0, 0 },
        .renderer = undefined,
        .atlas = undefined,
    };

    self.renderer = try Renderer.create(self);
    self.atlas = try SDFFontAtlas.create(self);
}

pub fn destroy(_: *const OpenGL) void {
    c.glfwTerminate();
}

pub fn add_shader(_: *const OpenGL, vertex_shader_src: [*:0]const u8, fragment_shader_src: [*:0]const u8) !u32 {
    const vertex_shader: u32 = c.glad_glCreateShader.?(c.GL_VERTEX_SHADER);
    c.glad_glShaderSource.?(vertex_shader, 1, &vertex_shader_src, null);
    c.glad_glCompileShader.?(vertex_shader);

    const fragment_shader: u32 = c.glad_glCreateShader.?(c.GL_FRAGMENT_SHADER);
    c.glad_glShaderSource.?(fragment_shader, 1, &fragment_shader_src, null);
    c.glad_glCompileShader.?(fragment_shader);

    var success: i32 = undefined;
    var infoLog: [512:0]u8 = undefined;
    c.glad_glGetShaderiv.?(fragment_shader, c.GL_COMPILE_STATUS, &success);

    if (success == c.GL_FALSE) {
        c.glad_glGetShaderInfoLog.?(fragment_shader, 512, null, &infoLog);
        std.debug.print("Fragment Shader Error:\n{s}", .{infoLog});
        return error.ShaderCompilationFailed;
    }

    c.glad_glGetShaderiv.?(vertex_shader, c.GL_COMPILE_STATUS, &success);

    if (success == c.GL_FALSE) {
        c.glad_glGetShaderInfoLog.?(vertex_shader, 512, null, &infoLog);
        std.debug.print("Vertex Shader Error:\n{s}", .{infoLog});
        return error.ShaderCompilationFailed;
    }

    const shader: u32 = c.glad_glCreateProgram.?();
    c.glad_glAttachShader.?(shader, vertex_shader);
    c.glad_glAttachShader.?(shader, fragment_shader);
    c.glad_glLinkProgram.?(shader);

    c.glad_glUseProgram.?(shader);

    c.glad_glDeleteShader.?(vertex_shader);
    c.glad_glDeleteShader.?(fragment_shader);

    c.glad_glGetProgramiv.?(shader, c.GL_LINK_STATUS, &success);

    if (success == c.GL_FALSE) {
        c.glad_glGetProgramInfoLog.?(shader, 512, null, &infoLog);
        std.debug.print("Shader Program Linking Error:\n{s}", .{infoLog});
        return error.ShaderLinkingFailed;
    }

    c.glad_glUseProgram.?(0);

    return shader;
}

pub inline fn translateNDC(self: *const OpenGL, vertex: zm.Vec2f) zm.Vec2f {
    return .{
        ((vertex[0] / self.screen_size.width) * 2) - 1,
        ((vertex[1] / -self.screen_size.height) * 2) + 1,
    };
}

pub fn renderQuad(
    self: *const OpenGL,
    vertices: anytype,
    vertex_count: *u32,
    indices: [*]u32,
    index_count: *u32,
    bounds: *const Bounds,
) void {
    vertices[vertex_count.*].position = self.translateNDC(.{
        bounds.x,
        bounds.y,
    });
    vertices[vertex_count.* + 1].position = self.translateNDC(.{
        (bounds.x + bounds.width),
        bounds.y,
    });
    vertices[vertex_count.* + 2].position = self.translateNDC(.{
        bounds.x + bounds.width,
        bounds.y + bounds.height,
    });
    vertices[vertex_count.* + 3].position = self.translateNDC(.{
        bounds.x,
        bounds.y + bounds.height,
    });

    indices[index_count.*] = 2 + vertex_count.*;
    indices[index_count.* + 1] = 1 + vertex_count.*;
    indices[index_count.* + 2] = 0 + vertex_count.*;

    indices[index_count.* + 3] = 2 + vertex_count.*;
    indices[index_count.* + 4] = 0 + vertex_count.*;
    indices[index_count.* + 5] = 3 + vertex_count.*;

    vertex_count.* += 4;
    index_count.* += 6;
}
