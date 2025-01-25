const DebugUI = @import("DebugUI.zig");
const Button = @import("Button.zig");
const Rectangle = @import("Primatives.zig").Rectangle;
const Color = @import("Primatives.zig").Color;

pub const Element = union(enum) { button: Button };

pub const ElementBounds = struct {
    height: f32,
    width: f32,
};

pub const Events = packed struct {
    mouse_over: bool,
    hover_enter: bool,
    hover_exit: bool,
    mouse_down: bool,
    mouse_up: bool,
    mouse_held: bool,
    _padding: u2,
};

pub const PanelStencil = struct {
    x: f32,
    y: f32,

    pub fn getEvents(self: *const PanelStencil, ui: *const DebugUI, bounds: *const ElementBounds) ?Events {
        const hovering_now = self.x < ui.mouse_x and ui.mouse_x < self.x + bounds.width and
            self.y < ui.mouse_y and ui.mouse_y < self.y + bounds.height;

        if (!hovering_now) return null;

        const hovering_before = self.x < ui.last_mouse_x and ui.last_mouse_x < self.x + bounds.width and
            self.y < ui.last_mouse_y and ui.last_mouse_y < self.y + bounds.height;

        return Events{
            ._padding = 0,
            .mouse_over = hovering_now,
            .hover_enter = hovering_now and !hovering_before,
            .hover_exit = !hovering_now and hovering_before,
            .mouse_down = ui.mouse_down and !ui.last_mouse_down,
            .mouse_up = !ui.mouse_down and ui.last_mouse_down,
            .mouse_held = ui.mouse_down,
        };
    }
};

pub const PanelStencilCreator = struct {
    panel: *const Panel,
    height_used: f32,
    width_used: f32,
    max_height: f32,

    pub fn getStencil(self: *PanelStencilCreator, bounds: *const ElementBounds) PanelStencil {
        var offset_x = self.panel.x;
        var offset_y = self.panel.y;

        if (bounds.width < self.panel.width - self.width_used) {
            offset_x += self.width_used;
            offset_y += self.height_used;
            self.max_height = @max(self.max_height, bounds.height);
        } else {
            self.height_used += self.max_height;
            self.max_height = bounds.height;
            offset_x += 0;
            offset_y += self.height_used;
            self.width_used = bounds.width;
        }

        return PanelStencil{ .x = offset_x, .y = offset_y };
    }
};

pub const Panel = struct {
    x: f32,
    y: f32,
    height: f32,
    width: f32,

    pub const PADDING = 5;

    pub fn create(x: f32, y: f32, width: f32, height: f32) Panel {
        return Panel{
            .x = x + PADDING,
            .y = y + PADDING,
            .width = width - PADDING * 2,
            .height = height - PADDING * 2,
        };
    }

    pub fn getStencilCreator(self: *const Panel) PanelStencilCreator {
        return PanelStencilCreator{
            .height_used = 0.0,
            .width_used = 0.0,
            .max_height = 0.0,
            .panel = self,
        };
    }

    pub fn render(self: *const Panel, ui: *DebugUI) void {
        ui.primatives.addRectangle(Rectangle{
            .color = Color.gray(50),
            .x = self.x - PADDING,
            .y = self.y - PADDING,
            .width = self.width + PADDING * 2,
            .height = self.height + PADDING * 2,
        });
    }
};
