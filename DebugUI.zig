const Primatives = @import("Primatives.zig");
const Panel = @import("Panel.zig");
const Button = @import("Button.zig");
const Bounds = @import("utils.zig").Bounds;
const Extents = @import("utils.zig").Extents;

const DebugUI = @This();

const MAX_LAYOUTS = 64;
const MAX_ELEMENTS = 2048;

active_element: Element,
layout_stack_position: u32,
layout_stack: [MAX_LAYOUTS]ElementLayout,

mouse_down: bool,
mouse_x: f32,
mouse_y: f32,

last_mouse_down: bool,
last_mouse_x: f32,
last_mouse_y: f32,

delta_time: f32,

primatives: Primatives,

pub const Events = packed struct {
    mouse_over: bool,
    hover_enter: bool,
    hover_exit: bool,
    mouse_down: bool,
    mouse_up: bool,
    mouse_held: bool,
    _padding: u2,
};

pub const Element = union(enum) { button: Button };

pub const ElementLayout = union(enum) { panel: Panel };

pub inline fn newFrame(self: *DebugUI, mouse_x: f32, mouse_y: f32, mouse_down: bool, delta_time: f32) void {
    self.delta_time = delta_time;

    self.last_mouse_down = self.mouse_down;
    self.last_mouse_x = self.mouse_x;
    self.last_mouse_y = self.mouse_y;

    self.mouse_x = mouse_x;
    self.mouse_y = mouse_y;
    self.mouse_down = mouse_down;
}

pub inline fn beginLayout(self: *DebugUI, layout: ElementLayout) void {
    self.layout_stack[self.layout_stack_position] = layout;
    self.layout_stack_position += 1;
}

pub inline fn iterLayout(self: *DebugUI, extents: Extents) Bounds {
    return switch (self.layout_stack[self.layout_stack_position - 1]) {
        .panel => |*layout| layout.iterLayout(extents),
    };
}

pub inline fn getSpace(self: *DebugUI) Extents {
    return switch (self.layout_stack[self.layout_stack_position - 1]) {
        .panel => |*layout| layout.getSpace(),
    };
}

pub inline fn endLayout(self: *DebugUI) void {
    self.layout_stack_position -= 1;
}

pub fn getEvents(self: *const DebugUI, bounds: *const Bounds) ?Events {
    const hovering_now = bounds.x < self.mouse_x and self.mouse_x < bounds.x + bounds.width and
        bounds.y < self.mouse_y and self.mouse_y < bounds.y + bounds.height;

    if (!hovering_now) return null;

    const hovering_before = bounds.x < self.last_mouse_x and self.last_mouse_x < bounds.x + bounds.width and
        bounds.y < self.last_mouse_y and self.last_mouse_y < bounds.y + bounds.height;

    return Events{
        ._padding = 0,
        .mouse_over = hovering_now,
        .hover_enter = hovering_now and !hovering_before,
        .hover_exit = !hovering_now and hovering_before,
        .mouse_down = self.mouse_down and !self.last_mouse_down,
        .mouse_up = !self.mouse_down and self.last_mouse_down,
        .mouse_held = self.mouse_down,
    };
}

pub fn init() DebugUI {
    return DebugUI{
        .active_element = undefined,
        .last_mouse_down = false,
        .layout_stack = undefined,
        .layout_stack_position = 0,
        .mouse_down = false,
        .mouse_x = 0,
        .mouse_y = 0,
        .last_mouse_x = 0,
        .last_mouse_y = 0,
        .delta_time = 1.0 / 60.0,
        .primatives = Primatives{
            .rectangle_count = 0,
            .rectangles = undefined,
            .text_count = 0,
            .text = undefined,
        },
    };
}
