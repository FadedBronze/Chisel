const std = @import("std");
const DebugUI = @import("../DebugUI.zig");
const utils = @import("../utils.zig");
const Primatives = @import("../Primatives.zig");
const layout = @import("index.zig");

const Bounds = utils.Bounds;
const Extents = utils.Extents;
const ElementLayout = layout.ElementLayout;
const Rectangle = Primatives.Rectangle;
const Color = Primatives.Color;

const Grid = @This();

const PADDING = 5;

const MAX_GRID_SIZE = 64;

const GridPositioning = packed struct { row: u8, col: u8, row_span: u8, col_span: u8 };

rows: u8,
cols: u8,

positioning: GridPositioning,
bounds: Bounds,
filled_cells: [MAX_GRID_SIZE][MAX_GRID_SIZE / 8]u8,

pub fn iterLayout(self: *Grid, _: Extents) Bounds {
    const x_cell_size = @divExact(self.bounds.width - PADDING * @as(f32, @floatFromInt(self.rows - 1)), @as(f32, @floatFromInt(self.rows)));
    const y_cell_size = @divExact(self.bounds.height - PADDING * @as(f32, @floatFromInt(self.cols - 1)), @as(f32, @floatFromInt(self.cols)));

    const bounds = Bounds{
        .x = x_cell_size * @as(f32, @floatFromInt(self.positioning.row)) + self.bounds.x + @as(f32, @floatFromInt(self.positioning.row)) * PADDING,
        .y = y_cell_size * @as(f32, @floatFromInt(self.positioning.col)) + self.bounds.y + @as(f32, @floatFromInt(self.positioning.col)) * PADDING,
        .width = x_cell_size * @as(f32, @floatFromInt(self.positioning.row_span)) + @as(f32, @floatFromInt(self.positioning.row_span - 1)) * PADDING,
        .height = y_cell_size * @as(f32, @floatFromInt(self.positioning.col_span)) + @as(f32, @floatFromInt(self.positioning.col_span - 1)) * PADDING,
    };

    return bounds;
}

pub fn getSpace(self: *Grid) Extents {
    const x_cell_size = @divExact(self.bounds.width - PADDING * @as(f32, @floatFromInt(self.rows - 1)), @as(f32, @floatFromInt(self.rows)));
    const y_cell_size = @divExact(self.bounds.height - PADDING * @as(f32, @floatFromInt(self.cols - 1)), @as(f32, @floatFromInt(self.cols)));

    return Extents{
        .width = x_cell_size * @as(f32, @floatFromInt(self.positioning.row_span)) + @as(f32, @floatFromInt(self.positioning.row_span - 1)) * PADDING,
        .height = y_cell_size * @as(f32, @floatFromInt(self.positioning.col_span)) + @as(f32, @floatFromInt(self.positioning.col_span - 1)) * PADDING,
    };
}

pub fn position(ui: *DebugUI, row: u8, col: u8, row_span: u8, col_span: u8) void {
    std.debug.assert(switch (ui.layout_stack[ui.layout_stack_position - 1]) {
        .grid => true,
        else => false,
    });

    var grid = &ui.layout_stack[ui.layout_stack_position - 1].grid;

    std.debug.assert(row < grid.rows and row >= 0 and col < grid.cols and col >= 0);
    std.debug.assert(row_span + row <= grid.rows);
    std.debug.assert(col_span + col <= grid.cols);

    var i: usize = row;
    while (i < row_span) : (i += 1) {
        var j: usize = col;
        while (j < col_span) : (j += 1) {
            const mask = @as(u8, 1) << @intCast(i % 8);
            std.debug.assert(grid.filled_cells[j][@divTrunc(i, 8)] & mask == 0);
            grid.filled_cells[j][@divTrunc(i, 8)] ^= mask;
        }
    }

    grid.positioning = GridPositioning{
        .col = col,
        .row = row,
        .col_span = col_span,
        .row_span = row_span,
    };
}

pub fn start(ui: *DebugUI, bounds: Bounds, rows: u8, cols: u8) void {
    const max_extents = ui.getSpace();

    std.debug.assert(utils.almost_le(bounds.width, max_extents.width));
    std.debug.assert(utils.almost_le(bounds.height, max_extents.height));

    var grid: [MAX_GRID_SIZE][MAX_GRID_SIZE / 8]u8 = undefined;

    var i: usize = 0;

    while (i < @divTrunc(rows, 8)) : (i += 1) {
        var j: usize = 0;

        while (j < cols) : (j += 1) {
            grid[j][i] = 0;
        }
    }

    ui.beginLayout(ElementLayout{
        .grid = Grid{
            .rows = rows,
            .cols = cols,
            .filled_cells = grid,
            .positioning = .{
                .row_span = 0,
                .col_span = 0,
                .row = 0,
                .col = 0,
            },
            .bounds = ui.iterLayout(Extents{ .width = bounds.width, .height = bounds.height }),
        },
    });
}

pub fn end(ui: *DebugUI) void {
    ui.endLayout();
}
