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

const OpenGL = @This();

window: *c.GLFWwindow,
screen_size: Extents,

vertices: union {
    ui: [2048]Backend.Vertex,
},
vertex_count: u32,

indices: [4096]u32,
index_count: u32,

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

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    //c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    const window = c.glfwCreateWindow(width_int, height_int, "Hello World", null, null);

    if (window == null) {
        c.glfwTerminate();
        return error.GLFWWindowInitFailed;
    }

    c.glfwMakeContextCurrent(window);

    c.glViewport(0, 0, width_int, height_int);

    c.glfwSetWindowUserPointer(window, self);

    _ = c.glfwSetFramebufferSizeCallback(window, frameBufferSizeCallback);

    const err: c.GLenum = c.glewInit();

    if (c.GLEW_OK != err) {
        std.debug.print("{s}", .{c.glewGetErrorString(err)});
        return error.GLEWInitFailed;
    }

    c.glEnable(c.GL_DEBUG_OUTPUT);
    c.__glewDebugMessageCallback.?(debugCallback, null);

    self.vertices = undefined;
    self.vertex_count = 0;
    self.indices = undefined;
    self.screen_size = Extents{ .height = height, .width = width };
    self.index_count = 0;
    self.window = window.?;
}

pub fn destroy(_: *OpenGL) void {
    c.glfwTerminate();
}

pub fn create_backend(self: *OpenGL) !Backend {
    const vertex_shader: u32 = c.__glewCreateShader.?(c.GL_VERTEX_SHADER);
    c.__glewShaderSource.?(vertex_shader, 1, &Backend.VERTEX_SHADER_SOURCE, null);
    c.__glewCompileShader.?(vertex_shader);

    const fragment_shader: u32 = c.__glewCreateShader.?(c.GL_FRAGMENT_SHADER);
    c.__glewShaderSource.?(fragment_shader, 1, &Backend.FRAGMENT_SHADER_SOURCE, null);
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

    var vao: u32 = undefined;
    c.__glewGenVertexArrays.?(1, &vao);
    c.__glewBindVertexArray.?(vao);

    var ebo: u32 = undefined;
    c.__glewGenBuffers.?(1, &ebo);
    c.__glewBindBuffer.?(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.__glewBufferData.?(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(u32) * self.indices.len, null, c.GL_DYNAMIC_DRAW);

    var vbo: u32 = undefined;
    c.__glewGenBuffers.?(1, &vbo);
    c.__glewBindBuffer.?(c.GL_ARRAY_BUFFER, vbo);
    c.__glewBufferData.?(c.GL_ARRAY_BUFFER, @sizeOf(Backend.Vertex) * self.vertices.ui.len, null, c.GL_DYNAMIC_DRAW);

    c.__glewVertexAttribPointer.?(0, 2, c.GL_FLOAT, c.GL_FALSE, @sizeOf(Backend.Vertex), null);
    c.__glewVertexAttribPointer.?(1, 4, c.GL_UNSIGNED_BYTE, c.GL_TRUE, @sizeOf(Backend.Vertex), @ptrFromInt(@offsetOf(Backend.Vertex, "color")));

    c.__glewEnableVertexAttribArray.?(0);
    c.__glewEnableVertexAttribArray.?(1);

    return Backend{
        .vao = vao,
        .opengl = self,
        .shader = shader,
    };
}

pub const Backend = struct {
    opengl: *OpenGL,
    shader: u32,
    vao: u32,

    const Vertex = packed struct {
        x: f32,
        y: f32,
        color: Primatives.Color,
    };

    const VERTEX_SHADER_SOURCE: [*:0]const u8 =
        \\#version 330 core
        \\layout (location = 0) in vec2 aPos;
        \\layout (location = 1) in vec4 aColor;
        \\
        \\out vec4 vertexColor;
        \\
        \\void main()
        \\{
        \\    vertexColor = aColor;
        \\    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
        \\}
    ;

    const FRAGMENT_SHADER_SOURCE: [*:0]const u8 =
        \\#version 330 core
        \\
        \\out vec4 FragColor;
        \\in vec4 vertexColor;
        \\
        \\void main()
        \\{
        \\    FragColor = vertexColor;
        \\}
    ;

    pub fn renderQuad(self: *Backend, bounds: *const Bounds, color: Primatives.Color) void {
        self.opengl.vertices.ui[self.opengl.vertex_count] = Vertex{
            .x = bounds.x / self.opengl.screen_size.width,
            .y = bounds.y / self.opengl.screen_size.height,
            .color = color,
        };
        self.opengl.vertices.ui[self.opengl.vertex_count + 1] = Vertex{
            .x = (bounds.x + bounds.width) / self.opengl.screen_size.width,
            .y = bounds.y / self.opengl.screen_size.height,
            .color = color,
        };
        self.opengl.vertices.ui[self.opengl.vertex_count + 2] = Vertex{
            .x = (bounds.x + bounds.width) / self.opengl.screen_size.width,
            .y = (bounds.y + bounds.height) / self.opengl.screen_size.height,
            .color = color,
        };
        self.opengl.vertices.ui[self.opengl.vertex_count + 3] = Vertex{
            .x = bounds.x / self.opengl.screen_size.width,
            .y = (bounds.y + bounds.height) / self.opengl.screen_size.height,
            .color = color,
        };

        self.opengl.indices[self.opengl.index_count] = 2 + self.opengl.vertex_count;
        self.opengl.indices[self.opengl.index_count + 1] = 1 + self.opengl.vertex_count;
        self.opengl.indices[self.opengl.index_count + 2] = 0 + self.opengl.vertex_count;

        self.opengl.indices[self.opengl.index_count + 3] = 2 + self.opengl.vertex_count;
        self.opengl.indices[self.opengl.index_count + 4] = 0 + self.opengl.vertex_count;
        self.opengl.indices[self.opengl.index_count + 5] = 3 + self.opengl.vertex_count;

        self.opengl.vertex_count += 4;
        self.opengl.index_count += 6;
    }

    pub fn render(self: *Backend, primatives: *const Primatives) !void {
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        self.opengl.vertices = .{ .ui = undefined };
        self.opengl.vertex_count = 0;
        self.opengl.index_count = 0;
        self.opengl.indices = undefined;

        for (primatives.rectangles[0..primatives.rectangle_count]) |rectangle| {
            const bounds = Bounds{
                .height = rectangle.height,
                .width = rectangle.width,
                .x = rectangle.x,
                .y = rectangle.y,
            };

            self.renderQuad(&bounds, rectangle.color);
        }

        //std.debug.print("{any}\n", .{self.opengl.screen_size});

        c.__glewBindVertexArray.?(self.vao);
        c.__glewBufferSubData.?(c.GL_ARRAY_BUFFER, 0, @sizeOf(Vertex) * self.opengl.vertex_count, &self.opengl.vertices.ui);
        c.__glewBufferSubData.?(c.GL_ELEMENT_ARRAY_BUFFER, 0, @sizeOf(u32) * self.opengl.index_count, &self.opengl.indices);

        c.__glewUseProgram.?(self.shader);

        c.glDrawElements(c.GL_TRIANGLES, @intCast(self.opengl.index_count), c.GL_UNSIGNED_INT, null);

        c.glfwSwapBuffers(self.opengl.window);
        c.glfwPollEvents();
    }

    pub fn updateSize(self: *Backend, width: f32, height: f32) void {
        self.window_size[0] = width;
        self.window_size[1] = height;
    }

    pub fn getEvents(self: *Backend) InputEventInfo {
        return InputEventInfo{
            .flags = .{
                .quit = c.glfwWindowShouldClose(self.opengl.window) == c.GLFW_TRUE,
                .mouse_down = false,
                ._padding = 0,
            },
            .mouse_x = 0,
            .mouse_y = 0,
            .scroll_x = 0,
            .scroll_y = 0,
            .input_keys = undefined,
            .input_keys_count = 0,
        };
    }
};
