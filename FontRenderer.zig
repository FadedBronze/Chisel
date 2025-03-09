const std = @import("std");
const FontRenderer = @This();

const Font = struct {
    head_table: HeadTable,
    glyf_table: GlyfTable,
    loca_table: LocaTable,
    maxp_table: MaxpTable,
};

const OffsetSubtable = struct {
    scaler_type: u32,
    number_of_tables: u16,
    search_range: u16,
    entry_selector: u16,
    range_shift: u16,
};

const Tag = union {
    tag_uint32: u32,
    name: [4]u8,
};

const TableHeader = struct {
    tag: Tag,
    checksum: u32,
    offset: u32, // Doesn't make sense / don't need
    length: u32,
};

const TableDirectory = struct {
    glyf_table: TableHeader,
    loca_table: TableHeader,
    head_table: TableHeader,
    maxp_table: TableHeader,
    cmap_table: TableHeader,
    other_tables: [*]TableHeader,
};

const HeadTable = struct {
    version: u32,
    revision: u32,
    checksum_adjustment: u32,
    magic_number: u32,
    flags: u16,
    units_per_em: u16,
    created: u64,
    modified: u64,
    x_min: u16,
    y_min: u16,
    x_max: u16,
    y_max: u16,
    mac_style: u16,
    lowest_rec_PPEM: u16,
    font_direction_hint: i16,
    index_to_location_format: i16,
    glyph_data_format: i16,
};

const GlyfTable = [*]Glyph;

const Glyph = struct {
    number_of_contours: u16,
    x_min: u16,
    y_min: u16,
    x_max: u16,
    y_max: u16,
    end_points_of_contours: [*]u16,
    instruction_length: u16,
    instructions: [*]u16,
    flags: [*]u16,
    x_coordinates: [*]u8,
    y_coordinates: [*]u8,
};

const MaxpTable = struct {
    version: u32,
    number_of_glyphs: u16,
    max_points: u16,
    max_contours: u16,
    max_component_points: u16,
    max_component_contours: u16,
    max_zones: u16,
    max_twilight_points: u16,
    max_storage: u16,
    max_function_defs: u16,
    max_instruction_defs: u16,
    max_stack_elements: u16,
    max_size_of_instructions: u16,
    max_component_elements: u16,
    max_component_depth: u16,
};

const CmapTable = struct {};

const LocaTable = union {
    offsets16: [*]u16,
    offsets32: [*]u32,
};

const ByteWalker = struct {
    position: usize,
    slice: []const u8,

    fn new(slice: []const u8) ByteWalker {
        return ByteWalker{
            .position = 0,
            .slice = slice,
        };
    }

    fn skipBytes(self: *ByteWalker, bytes: usize) !void {
        if (self.position + bytes > self.slice.len) return error.EndOfBytes;
        self.position += bytes;
    }

    inline fn getChars(self: *ByteWalker, bytes: usize) ![]const u8 {
        if (self.position + bytes > self.slice.len) return error.EndOfBytes;
        const chars = self.slice[self.position .. self.position + bytes];
        self.position += bytes;
        return chars;
    }

    inline fn getUint64(self: *ByteWalker) !u64 {
        if (self.position + 8 > self.slice.len) return error.EndOfBytes;

        var bytes: [8]u8 = undefined;

        var i: usize = 0;
        while (i < 8) : (i += 1) {
            bytes[i] = self.slice[self.position + i];
        }

        self.position += 8;

        return std.mem.bigToNative(u64, std.mem.bytesToValue(u64, &bytes));
    }

    inline fn getUint32(self: *ByteWalker) !u32 {
        if (self.position + 4 > self.slice.len) return error.EndOfBytes;
        const ptr: *const u32 = @alignCast(@ptrCast(self.slice.ptr + self.position));
        self.position += 4;
        return std.mem.bigToNative(u32, ptr.*);
    }

    inline fn getUint16(self: *ByteWalker) !u16 {
        if (self.position + 2 > self.slice.len) return error.EndOfBytes;
        const ptr: *const u16 = @alignCast(@ptrCast(self.slice.ptr + self.position));
        self.position += 2;
        return std.mem.bigToNative(u16, ptr.*);
    }

    inline fn getInt16(self: *ByteWalker) !i16 {
        if (self.position + 2 > self.slice.len) return error.EndOfBytes;
        const ptr: *const i16 = @alignCast(@ptrCast(self.slice.ptr + self.position));
        self.position += 2;
        return std.mem.bigToNative(i16, ptr.*);
    }

    inline fn jumpTo(self: *ByteWalker, offset: usize) !void {
        if (offset > self.slice.len) return error.EndOfBytes;
        self.position = offset;
    }
};

fn getTableData(raw_font_bytes: []const u8) !struct { offset_subtable: OffsetSubtable, table_directory: TableDirectory } {
    var offset_subtable: OffsetSubtable = undefined;
    var table_directory: TableDirectory = undefined;

    var byte_walker = ByteWalker.new(raw_font_bytes);

    offset_subtable = OffsetSubtable{
        .scaler_type = try byte_walker.getUint32(),
        .number_of_tables = try byte_walker.getUint16(),
        .search_range = try byte_walker.getUint16(),
        .entry_selector = try byte_walker.getUint16(),
        .range_shift = try byte_walker.getUint16(),
    };

    var headers_found: usize = 0;

    var i: usize = 0;
    while (i < offset_subtable.number_of_tables) : (i += 1) {
        const tag = (try byte_walker.getChars(4)).ptr;

        const header = TableHeader{
            .tag = .{ .name = @bitCast(tag[0..4].*) },
            .checksum = try byte_walker.getUint32(),
            .offset = try byte_walker.getUint32(),
            .length = try byte_walker.getUint32(),
        };

        if (std.mem.eql(u8, &header.tag.name, "loca")) {
            table_directory.loca_table = header;
            headers_found += 1;
        } else if (std.mem.eql(u8, &header.tag.name, "glyf")) {
            table_directory.glyf_table = header;
            headers_found += 1;
        } else if (std.mem.eql(u8, &header.tag.name, "head")) {
            table_directory.head_table = header;
            headers_found += 1;
        } else if (std.mem.eql(u8, &header.tag.name, "maxp")) {
            table_directory.maxp_table = header;
            headers_found += 1;
        } else if (std.mem.eql(u8, &header.tag.name, "cmap")) {
            table_directory.cmap_table = header;
            headers_found += 1;
        } else {
            //TODO
        }
    }

    std.debug.assert(headers_found == 5);

    std.debug.print("{any}\n", .{offset_subtable});
    std.debug.print("{any}\n", .{table_directory});

    return .{
        .offset_subtable = offset_subtable,
        .table_directory = table_directory,
    };
}

fn getFont(raw_font_bytes: []const u8, allocator: *std.mem.Allocator) !Font {
    var font: Font = undefined;

    const table_data = try getTableData(raw_font_bytes);

    var byte_walker = ByteWalker.new(raw_font_bytes);

    try byte_walker.jumpTo(table_data.table_directory.head_table.offset);

    font.head_table = HeadTable{
        .version = try byte_walker.getUint32(),
        .revision = try byte_walker.getUint32(),
        .checksum_adjustment = try byte_walker.getUint32(),
        .magic_number = try byte_walker.getUint32(),
        .flags = try byte_walker.getUint16(),
        .units_per_em = try byte_walker.getUint16(),
        .created = try byte_walker.getUint64(),
        .modified = try byte_walker.getUint64(),
        .x_min = try byte_walker.getUint16(),
        .y_min = try byte_walker.getUint16(),
        .x_max = try byte_walker.getUint16(),
        .y_max = try byte_walker.getUint16(),
        .mac_style = try byte_walker.getUint16(),
        .lowest_rec_PPEM = try byte_walker.getUint16(),
        .font_direction_hint = try byte_walker.getInt16(),
        .index_to_location_format = try byte_walker.getInt16(),
        .glyph_data_format = try byte_walker.getInt16(),
    };

    std.debug.print("{any}\n", .{font.head_table});

    try byte_walker.jumpTo(table_data.table_directory.maxp_table.offset);

    font.maxp_table = MaxpTable{
        .version = try byte_walker.getUint32(),
        .number_of_glyphs = try byte_walker.getUint16(),
        .max_points = try byte_walker.getUint16(),
        .max_contours = try byte_walker.getUint16(),
        .max_component_points = try byte_walker.getUint16(),
        .max_component_contours = try byte_walker.getUint16(),
        .max_zones = try byte_walker.getUint16(),
        .max_twilight_points = try byte_walker.getUint16(),
        .max_storage = try byte_walker.getUint16(),
        .max_function_defs = try byte_walker.getUint16(),
        .max_instruction_defs = try byte_walker.getUint16(),
        .max_stack_elements = try byte_walker.getUint16(),
        .max_size_of_instructions = try byte_walker.getUint16(),
        .max_component_elements = try byte_walker.getUint16(),
        .max_component_depth = try byte_walker.getUint16(),
    };

    std.debug.print("{any}\n", .{font.maxp_table});

    try byte_walker.jumpTo(table_data.table_directory.glyf_table.offset);

    font.glyf_table = (try allocator.alloc(Glyph, font.maxp_table.number_of_glyphs)).ptr;

    var i: usize = 0;
    while (i < font.maxp_table.number_of_glyphs) : (i += 1) {}

    return font;
}

pub fn create(font_path: []const u8) !FontRenderer {
    var raw_tff_buffer: [64000]u8 = undefined;

    var fixed_buffer: [64000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&fixed_buffer);
    var allocator = fba.allocator();

    const raw_tff_data = try std.fs.cwd().readFile(font_path, &raw_tff_buffer);

    _ = try getFont(raw_tff_data, &allocator);

    return FontRenderer{};
}

const WIDTH = 512;
const HEIGHT = 512;
