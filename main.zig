const std = @import("std");
const gl = @import("gl");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_opengl.h");
    @cInclude("dcimgui.h");
    @cInclude("backends/dcimgui_impl_sdl3.h");
    @cInclude("backends/dcimgui_impl_opengl3.h");
});

const palette_data = @embedFile("bp962a.u45");
const sprite_data = [2][:0]const u8{
    @embedFile("bp962a.u76"),
    @embedFile("bp962a.u77"),
};
const tileset_data = .{
    @embedFile("bp962a.u53"),
    @embedFile("bp962a.u54"),
    @embedFile("bp962a.u57"),
};

var window: ?*c.SDL_Window = undefined;

const window_w = 1280;
const window_h = 800;

var palette_texture: gl.uint = undefined;
var palette_offset: usize = 260320;

var sprite_texture: gl.uint = undefined;
var sprite_offset: usize = 0;
var sprite_bank: usize = 0;

fn texture_load(pixels: ?[]const u8, width: u16, height: u16, components: u3) gl.uint {
    var textures: [1]gl.uint = undefined;
    gl.GenTextures(1, &textures);
    gl.BindTexture(gl.TEXTURE_2D, textures[0]);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.TexImage2D(gl.TEXTURE_2D, 0, switch (components) {
        1 => gl.RED,
        4 => gl.RGBA,
        else => unreachable,
    }, width, height, 0, switch (components) {
        1 => gl.RED,
        4 => gl.RGBA,
        else => unreachable,
    }, gl.UNSIGNED_BYTE, if (pixels) |p| p.ptr else null);
    return textures[0];
}

fn texture_update(texture: gl.uint, pixels: []const u8, width: u16, height: u16, components: u3) void {
    gl.BindTexture(gl.TEXTURE_2D, texture);
    gl.TexSubImage2D(gl.TEXTURE_2D, 0, 0, 0, width, height, switch (components) {
        1 => gl.RED,
        4 => gl.RGBA,
        else => unreachable,
    }, gl.UNSIGNED_BYTE, pixels.ptr);
}

pub fn main() !void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    const GLSL_VERSION = "#version 330";
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_FLAGS, 0);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MAJOR_VERSION, 3);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_CONTEXT_MINOR_VERSION, 3);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DOUBLEBUFFER, 1);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_DEPTH_SIZE, 24);
    _ = c.SDL_GL_SetAttribute(c.SDL_GL_STENCIL_SIZE, 8);

    window = c.SDL_CreateWindow("Air Gallet", window_w, window_h, c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE);
    const context = c.SDL_GL_CreateContext(window);

    _ = c.SDL_GL_MakeCurrent(window, context);
    _ = c.SDL_GL_SetSwapInterval(1);

    var procs: gl.ProcTable = undefined;
    if (!procs.init(c.SDL_GL_GetProcAddress)) return error.InitFailed;
    gl.makeProcTableCurrent(&procs);

    _ = c.ImGui_CreateContext(null);
    const imio = c.ImGui_GetIO();
    imio.*.ConfigFlags = c.ImGuiConfigFlags_NavEnableKeyboard;

    _ = c.cImGui_ImplSDL3_InitForOpenGL(window.?, context.?);
    defer _ = c.cImGui_ImplSDL3_Shutdown();
    _ = c.cImGui_ImplOpenGL3_InitEx(GLSL_VERSION);
    defer _ = c.cImGui_ImplOpenGL3_Shutdown();

    var palette_pixels: [16 * 16 * 4]u8 = undefined;
    palette_texture = texture_load(&palette_pixels, 16, 16, 4);
    var sprite_pixels: [256 * 256 * 4]u8 = undefined;
    sprite_texture = texture_load(&sprite_pixels, 256, 256, 4);

    var running = true;
    while (running) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            _ = c.cImGui_ImplSDL3_ProcessEvent(&event);
            switch (event.type) {
                c.SDL_EVENT_QUIT => running = false,
                c.SDL_EVENT_KEY_DOWN => running = event.key.key != c.SDLK_ESCAPE,
                else => {},
            }
        }

        c.cImGui_ImplOpenGL3_NewFrame();
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();

        if (c.ImGui_Begin("Palette", null, 0)) {
            c.ImGui_Image(c.ImTextureRef{ ._TexID = palette_texture }, c.ImVec2{ .x = 256, .y = 256 });
            var offset: i32 = @intCast(palette_offset);
            _ = c.ImGui_InputIntEx("offset", &offset, 1, 256, c.ImGuiInputFlags_Repeat);
            palette_offset = @intCast(std.math.clamp(offset, 0, @as(i32, @intCast(palette_data.len / 2 - 256))));
            c.ImGui_End();
        }

        if (c.ImGui_Begin("Sprites", null, 0)) {
            c.ImGui_Image(c.ImTextureRef{ ._TexID = sprite_texture }, c.ImVec2{ .x = 256, .y = 256 });
            var bank: i32 = @intCast(sprite_bank);
            _ = c.ImGui_InputInt("bank", &bank);
            sprite_bank = @intCast(std.math.clamp(bank, 0, 1));

            var offset: i32 = @intCast(sprite_offset);
            _ = c.ImGui_InputIntEx("offset", &offset, 1, 64 * 256, c.ImGuiInputFlags_Repeat);
            sprite_offset = @intCast(std.math.clamp(offset, 0, @as(i32, @intCast(sprite_data[0].len - 256 * 256))));
            c.ImGui_End();
        }

        const palette16: []const u16 = std.mem.bytesAsSlice(u16, @as([]align(2) const u8, @alignCast(palette_data)))[@intCast(palette_offset)..][0..256];
        for (0..16) |y| {
            for (0..16) |x| {
                const i = y * 16 + x;
                const color16 = palette16[i];
                const red: u8 = @truncate(((color16 >> 0) & 0b11111) << 3);
                const green: u8 = @truncate(((color16 >> 5) & 0b11111) << 3);
                const blue: u8 = @truncate(((color16 >> 10) & 0b11111) << 3);
                palette_pixels[i * 4 + 0] = red;
                palette_pixels[i * 4 + 1] = green;
                palette_pixels[i * 4 + 2] = blue;
                palette_pixels[i * 4 + 3] = 0xff;
            }
        }
        texture_update(palette_texture, &palette_pixels, 16, 16, 4);

        const sprite_index: []const u8 = sprite_data[sprite_bank][@intCast(sprite_offset)..][0 .. 256 * 256];
        for (0..256) |y| {
            for (0..256) |x| {
                const i = y * 256 + x;
                // 4 bit indices
                var pi: u16 = sprite_index[i / 2];
                if (x & 1 == 0) {
                    pi &= 0xf;
                } else {
                    pi >>= 4;
                }
                sprite_pixels[i * 4 + 0] = palette_pixels[4 * pi + 0];
                sprite_pixels[i * 4 + 1] = palette_pixels[4 * pi + 1];
                sprite_pixels[i * 4 + 2] = palette_pixels[4 * pi + 2];
                sprite_pixels[i * 4 + 3] = palette_pixels[4 * pi + 3];
            }
        }
        texture_update(sprite_texture, &sprite_pixels, 256, 256, 4);

        c.ImGui_Render();

        gl.Viewport(0, 0, @intFromFloat(imio.*.DisplaySize.x), @intFromFloat(imio.*.DisplaySize.y));
        gl.ClearColor(0.4, 0.6, 0.9, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);
        c.cImGui_ImplOpenGL3_RenderDrawData(c.ImGui_GetDrawData());
        _ = c.SDL_GL_SwapWindow(window);
    }
}
