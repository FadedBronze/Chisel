const c = @cImport({
    @cInclude("freetype2/freetype/freetype.h");
    @cInclude("stb_image_write.h");
});

const std = @import("std");

const GlyphAtlasPosition = struct {
    characterCode: u32,
    x: u16,
    y: u16,
};

const SDFFontAtlas = @This();

const GLYPH_SIZE = 32;
const ATLAS_SIZE = 96;
const GLYPHS_PER_EXTENT = ATLAS_SIZE / GLYPH_SIZE;

fn roundDownToPow2(n: u32) u32 {
    if (n == 0) return 0;
    return @as(u32, 1) << (31 - @clz(n));
}

const MAX_GLYPHS = roundDownToPow2(GLYPHS_PER_EXTENT * GLYPHS_PER_EXTENT) - 1;

//faces: []*c.FT_Face,
pixels: [ATLAS_SIZE * ATLAS_SIZE]u8,
rendered_glyphs: [MAX_GLYPHS]GlyphAtlasPosition,
glyph_count: u16,
currentEviction: u16,

pub fn insert_glyph(self: *SDFFontAtlas, characterCode: u32) void {
    var foundGlyphIndex: i64 = -1;

    for (0..MAX_GLYPHS) |i| {
        if (self.rendered_glyphs[i].characterCode == characterCode) {
            foundGlyphIndex = @intCast(i);
        }
    }

    if (self.glyph_count < MAX_GLYPHS) {
        if (foundGlyphIndex == -1) {
            self.rendered_glyphs[self.glyph_count].characterCode = characterCode;
            self.rendered_glyphs[self.glyph_count].x = self.glyph_count % GLYPHS_PER_EXTENT;
            self.rendered_glyphs[self.glyph_count].y = self.glyph_count / GLYPHS_PER_EXTENT;
            self.glyph_count += 1;

            self.heapify_up(self.glyph_count - 1);
            self.rendered_glyphs[0].characterCode = characterCode;
        } else {
            self.heapify_up(@intCast(foundGlyphIndex));
            self.rendered_glyphs[0].characterCode = characterCode;
        }
    } else {
        if (self.currentEviction <= 1) {
            self.currentEviction = (MAX_GLYPHS + 1) / 2;
        } else {
            self.currentEviction -= 1;
        }

        self.heapify_up(self.glyph_count - self.currentEviction);
        self.rendered_glyphs[0].characterCode = characterCode;
    }
}

// 0
// 1 2
// 3 4 5 6

/// Takes a cell and replaces it with its parent and so on until reaching the root
fn heapify_up(self: *SDFFontAtlas, currentIdx: usize) void {
    if (currentIdx == 0) return;

    const nextIdx = if (currentIdx == 1) 0 else ((currentIdx - 1) / 2);

    const nextCharacterCode = self.rendered_glyphs[nextIdx];
    self.rendered_glyphs[currentIdx] = nextCharacterCode;

    if (nextIdx == 0) {
        return;
    }

    self.heapify_up(nextIdx);
}

pub fn create() SDFFontAtlas {
    return SDFFontAtlas{
        .pixels = undefined,
        .rendered_glyphs = undefined,
        .glyph_count = 0,
        .currentEviction = 0,
    };
}
