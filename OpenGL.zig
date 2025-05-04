const std = @import("std");

const c = @cImport({
    @cInclude("GL/glew.h");
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

vertices: union {
    ui: [2048]Renderer.Vertex,
    font: [2048]SDFFontAtlas.Vertex,
},
vertex_count: u32,

indices: [4096]u32,
index_count: u32,

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

    c.glViewport(0, 0, width_int, height_int);

    c.glfwSetWindowUserPointer(window, self);

    _ = c.glfwSetMouseButtonCallback(window, mouseButtonCallback);

    _ = c.glfwSetCursorPosCallback(window, cursorPositionCallback);

    _ = c.glfwSetFramebufferSizeCallback(window, frameBufferSizeCallback);

    _ = c.glfwSetScrollCallback(window, scrollCallback);

    const err: c.GLenum = c.glewInit();

    if (c.GLEW_OK != err) {
        std.debug.print("{s}", .{c.glewGetErrorString(err)});
        return error.GLEWInitFailed;
    }

    c.glEnable(c.GL_BLEND);
    c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);

    c.glEnable(c.GL_DEBUG_OUTPUT);
    c.__glewDebugMessageCallback.?(debugCallback, null);

    self.* = OpenGL{
        .vertices = undefined,
        .vertex_count = 0,
        .indices = undefined,
        .screen_size = Extents{ .height = height, .width = width },
        .index_count = 0,
        .atlas = try SDFFontAtlas.create(self),
        .renderer = try Renderer.create(self),
        .window = window.?,
        .mouse_down = false,
        .mouse_position = .{ 0, 0 },
        .scroll_offset = .{ 0, 0 },
    };
}

pub fn destroy(_: *OpenGL) void {
    c.glfwTerminate();
}

pub fn add_shader(_: *OpenGL, vertex_shader_src: [*:0]const u8, fragment_shader_src: [*:0]const u8) !u32 {
    const vertex_shader: u32 = c.__glewCreateShader.?(c.GL_VERTEX_SHADER);
    c.__glewShaderSource.?(vertex_shader, 1, &vertex_shader_src, null);
    c.__glewCompileShader.?(vertex_shader);

    const fragment_shader: u32 = c.__glewCreateShader.?(c.GL_FRAGMENT_SHADER);
    c.__glewShaderSource.?(fragment_shader, 1, &fragment_shader_src, null);
    c.__glewCompileShader.?(fragment_shader);

    var success: i32 = undefined;
    var infoLog: [512:0]u8 = undefined;
    c.__glewGetShaderiv.?(fragment_shader, c.GL_COMPILE_STATUS, &success);

    if (success == c.GL_FALSE) {
        c.__glewGetShaderInfoLog.?(fragment_shader, 512, null, &infoLog);
        std.debug.print("Fragment Shader Error:\n{s}", .{infoLog});
        return error.ShaderCompilationFailed;
    }

    c.__glewGetShaderiv.?(vertex_shader, c.GL_COMPILE_STATUS, &success);

    if (success == c.GL_FALSE) {
        c.__glewGetShaderInfoLog.?(vertex_shader, 512, null, &infoLog);
        std.debug.print("Vertex Shader Error:\n{s}", .{infoLog});
        return error.ShaderCompilationFailed;
    }

    const shader: u32 = c.__glewCreateProgram.?();
    c.__glewAttachShader.?(shader, vertex_shader);
    c.__glewAttachShader.?(shader, fragment_shader);
    c.__glewLinkProgram.?(shader);

    c.__glewUseProgram.?(shader);

    c.__glewDeleteShader.?(vertex_shader);
    c.__glewDeleteShader.?(fragment_shader);

    c.__glewGetProgramiv.?(shader, c.GL_LINK_STATUS, &success);

    if (success == c.GL_FALSE) {
        c.__glewGetProgramInfoLog.?(shader, 512, null, &infoLog);
        std.debug.print("Shader Program Linking Error:\n{s}", .{infoLog});
        return error.ShaderLinkingFailed;
    }

    return shader;
}

pub inline fn translateNDC(self: *OpenGL, vertex: zm.Vec2f) zm.Vec2f {
    return .{
        ((vertex[0] / self.screen_size.width) * 2) - 1,
        ((vertex[1] / -self.screen_size.height) * 2) + 1,
    };
}

pub fn renderQuad(
    self: *OpenGL,
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
