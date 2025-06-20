const Primatives = @import("Primatives.zig");

const utils = @import("utils.zig");

const Bounds = utils.Bounds;
const Extents = utils.Extents;
const Key = utils.Key;
const InputEventInfo = utils.InputEventInfo;

const DebugUI = @This();

const std = @import("std");

pub const FlexStrip = @import("layouts/FlexStrip.zig");
pub const Frame = @import("layouts/Frame.zig");
pub const Grid = @import("layouts/Grid.zig");
pub const Slider = @import("elements/Slider.zig");
pub const Button = @import("elements/Button.zig");
pub const Scroll = @import("elements/Scroll.zig");
pub const TextInput = @import("elements/TextInput.zig");
pub const Dropdown = @import("elements/Dropdown.zig");
pub const ScrollState = Scroll.State;

pub const ElementLayout = union(enum) { flex_strip: FlexStrip, grid: Grid, frame: Frame };
pub const Element = union(enum) { button: Button, slider: Slider, scroll: Scroll, text_input: TextInput, dropdown: Dropdown };
pub const RetainedState = struct {
    id: [64:0]u8,
    state: union {
        scroll: ScrollState,
    },
};

const MAX_LAYOUTS = 64;
const MAX_ELEMENTS = 2048;
const MAX_STATES = 128;

active_element: Element,
active_element_id: [64:0]u8,

layout_stack: [MAX_LAYOUTS]ElementLayout,
layout_stack_position: u32,

retained_state: [MAX_STATES]RetainedState,
retained_state_count: u32,

scroll_bounds: Bounds,

mouse_down: bool,
mouse_x: f32,
mouse_y: f32,
scroll_x: f32,
scroll_y: f32,

last_mouse_down: bool,
last_mouse_x: f32,
last_mouse_y: f32,

delta_time: f32,

primatives: Primatives,

keys: []const Key,

pub const Events = packed struct {
    mouse_over: bool,
    hover_enter: bool,
    hover_exit: bool,
    mouse_down: bool,
    mouse_up: bool,
    mouse_held: bool,
    mouse_moved: bool,
    _padding: u1,
};

pub fn getState(self: *DebugUI, id: [*:0]const u8) struct { is_undefined: bool, retained: *RetainedState } {
    var i: usize = 0;
    while (i < self.retained_state_count) : (i += 1) {
        if (std.mem.orderZ(u8, id, &self.retained_state[i].id).compare(.eq)) return .{
            .is_undefined = false,
            .retained = &self.retained_state[i],
        };
    }

    self.retained_state_count += 1;

    var state = RetainedState{
        .id = undefined,
        .state = undefined,
    };

    @memcpy(state.id[0..std.mem.span(id).len], id);

    self.retained_state[self.retained_state_count - 1] = state;

    return .{
        .is_undefined = true,
        .retained = &self.retained_state[self.retained_state_count - 1],
    };
}

pub inline fn newFrame(self: *DebugUI, mouse_x: f32, mouse_y: f32, scroll_x: f32, scroll_y: f32, mouse_down: bool, delta_time: f32, keys: []const Key) void {
    self.keys = keys;

    self.delta_time = delta_time;

    self.last_mouse_down = self.mouse_down;
    self.last_mouse_x = self.mouse_x;
    self.last_mouse_y = self.mouse_y;

    self.mouse_x = mouse_x;
    self.mouse_y = mouse_y;

    self.scroll_x = scroll_x;
    self.scroll_y = scroll_y;

    self.mouse_down = mouse_down;
}

pub inline fn beginLayout(self: *DebugUI, layout: ElementLayout) void {
    self.layout_stack[self.layout_stack_position] = layout;
    self.layout_stack_position += 1;
}

pub inline fn currentLayout(self: *DebugUI) *ElementLayout {
    return &self.layout_stack[self.layout_stack_position - 1];
}

pub inline fn endLayout(self: *DebugUI) void {
    self.layout_stack_position -= 1;
}

pub fn getEvents(self: *const DebugUI, bounds: *const Bounds) Events {
    const hovering_now = bounds.x < self.mouse_x and self.mouse_x < bounds.x + bounds.width and
        bounds.y < self.mouse_y and self.mouse_y < bounds.y + bounds.height;

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
        .mouse_moved = self.mouse_x != self.last_mouse_x or self.mouse_y != self.last_mouse_y,
    };
}

pub inline fn compareId(ui: *const DebugUI, id: [*:0]const u8) bool {
    return std.mem.orderZ(u8, id, &ui.active_element_id).compare(.eq);
}

pub inline fn setId(ui: *DebugUI, id: [*:0]const u8) void {
    return @memcpy(ui.active_element_id[0 .. std.mem.span(id).len + 1], id);
}

pub fn start(ui: *DebugUI, window_size: Extents, events: *const InputEventInfo) void {
    ui.newFrame(
        events.mouse_x,
        events.mouse_y,
        events.scroll_x,
        events.scroll_y,
        events.flags.mouse_down,
        1.0 / 60.0,
        events.input_keys[0..events.input_keys_count],
    );
    ui.primatives.clear();

    ui.primatives.start_clip(0, 0, window_size.width, window_size.height);
}

pub fn end(ui: *DebugUI, backend: anytype) !void {
    ui.primatives.end_clip();
    //const starttime = std.time.milliTimestamp();
    try backend.render(&ui.primatives);
    //const endtime = std.time.milliTimestamp();
    //std.debug.print("Render time: {}\n", .{endtime - starttime});
}

pub fn init() DebugUI {
    var active_element_id: [64:0]u8 = undefined;
    active_element_id[0] = 0;

    return DebugUI{
        .active_element = undefined,
        .active_element_id = active_element_id,
        .last_mouse_down = false,
        .layout_stack = undefined,
        .layout_stack_position = 0,
        .retained_state = undefined,
        .retained_state_count = 0,
        .mouse_down = false,
        .mouse_x = 0,
        .mouse_y = 0,
        .last_mouse_x = 0,
        .last_mouse_y = 0,
        .scroll_x = 0,
        .scroll_y = 0,
        .delta_time = 1.0 / 60.0,
        .scroll_bounds = Bounds.max_bounds(),
        .keys = &[0]Key{},
        .primatives = Primatives.init(),
    };
}
