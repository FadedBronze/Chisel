const Button = @This();
const DebugUI = @import("DebugUI.zig");

const PanelStencilCreator = @import("elements.zig").PanelStencilCreator;
const Panel = @import("elements.zig").Panel;
const PanelStencil = @import("elements.zig").PanelStencil;
const ElementBounds = @import("elements.zig").ElementBounds;

const Primatives = @import("Primatives.zig");

hover_duration: f32,

const PADDING = 10;

pub fn create(ui: *DebugUI, font_backend: anytype, stencil_creator: *PanelStencilCreator, text: []const u8, _: ?[]const u8) void {
    const button_height = font_backend.getLineHeight(0) + PADDING * 2;

    const bounds = ElementBounds{
        .width = stencil_creator.panel.width,
        .height = button_height + Panel.PADDING,
    };

    const stencil = stencil_creator.getStencil(&bounds);

    const text_block = Primatives.TextBlock{
        .x = PADDING + stencil.x,
        .y = PADDING + stencil.y,
        .width = bounds.width - PADDING * 2,
        .text = text,
        .color = Primatives.Color.white(),
        .text_align = Primatives.TextAlign.Center,
        .text_break = Primatives.TextBreak.Word,
        .font_id = 0,
    };

    const base = Primatives.Rectangle{
        .x = stencil.x,
        .y = stencil.y,
        .width = bounds.width,
        .height = button_height,
        .color = Primatives.Color.gray(100),
    };

    ui.primatives.addRectangle(base);
    ui.primatives.addText(text_block);

    const local_events = stencil.getEvents(ui, &bounds) orelse return;

    if (local_events.hover_enter) {
        ui.active_element.button = Button{
            .hover_duration = 0,
        };
    }

    const hover = Primatives.Rectangle{
        .x = stencil.x,
        .y = stencil.y,
        .width = bounds.width,
        .height = button_height,
        .color = Primatives.Color.gray(122),
    };

    if (local_events.mouse_held and local_events.mouse_over) {
        ui.primatives.addRectangle(hover);
    }

    const tooltip_base = Primatives.Rectangle{
        .x = ui.mouse_x,
        .y = ui.mouse_y,
        .width = 120.0,
        .height = 12.0 + 5 * 2,
        .color = Primatives.Color.gray(122),
    };

    if (local_events.mouse_over) {
        ui.active_element.button.hover_duration += ui.delta_time;
    } else {
        ui.active_element.button.hover_duration = 0;
    }

    if (ui.active_element.button.hover_duration > 1.0) {
        ui.active_element.button.hover_duration = @min(ui.active_element.button.hover_duration, 15.0);
        ui.primatives.addRectangle(tooltip_base);
    }
}
