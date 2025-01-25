const std = @import("std");

const DebugUI = @This();
const Panel = @import("elements.zig").Panel;
const Element = @import("elements.zig").Element;
const Primatives = @import("Primatives.zig");

const MAX_PANELS = 64;
const MAX_ELEMENTS = 2048;

panels: [MAX_PANELS]Panel,
panel_count: u32,
active_element: Element,

mouse_down: bool,
mouse_x: f32,
mouse_y: f32,

last_mouse_down: bool,
last_mouse_x: f32,
last_mouse_y: f32,

delta_time: f32,

primatives: Primatives,

pub inline fn newFrame(self: *DebugUI, mouse_x: f32, mouse_y: f32, mouse_down: bool, delta_time: f32) void {
    self.delta_time = delta_time;

    self.last_mouse_down = self.mouse_down;
    self.last_mouse_x = self.mouse_x;
    self.last_mouse_y = self.mouse_y;

    self.mouse_x = mouse_x;
    self.mouse_y = mouse_y;
    self.mouse_down = mouse_down;
}

pub inline fn addPanel(self: *DebugUI, panel: *const Panel) u32 {
    self.panels[self.panel_count] = panel.*;
    self.panel_count += 1;
    return self.panel_count - 1;
}

pub fn init() DebugUI {
    return DebugUI{
        .panels = undefined,
        .panel_count = 0,
        .active_element = undefined,
        .last_mouse_down = false,
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

pub fn renderPanels(self: *DebugUI) void {
    for (self.panels) |panel| {
        panel.render(self);
    }
}
