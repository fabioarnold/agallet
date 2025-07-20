const std = @import("std");
const cimgui = @import("cimgui_zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const sdl_dep = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
    });
    const sdl_lib = sdl_dep.artifact("SDL3");
    exe_mod.linkLibrary(sdl_lib);

    const cimgui_dep = b.dependency("cimgui_zig", .{
        .target = target,
        .optimize = optimize,
        .platform = cimgui.Platform.SDL3,
        .renderer = cimgui.Renderer.OpenGL3,
        .gl_version = .@"3.3",
    });
    const cimgui_lib = cimgui_dep.artifact("cimgui");
    exe_mod.linkLibrary(cimgui_lib);
    exe_mod.addImport("gl", cimgui_lib.root_module.import_table.get("gl").?);

    const exe = b.addExecutable(.{
        .name = "agallet",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
