const std = @import("std");
const fs = std.fs;
const ArrayList = std.ArrayList;

const WIDTH = 500;
const HEIGHT = 500;

fn write_str(image_buffer: *std.ArrayList(u8), s: []const u8) !void {
    try image_buffer.appendSlice(s);
}

fn map(x: u32, in_min: u32, in_max: u32, out_min: u32, out_max: u32) u32 {
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

fn render(image_buffer: *std.ArrayList(u8)) !void {
    for ([_]u32{0} ** HEIGHT, 0..) |_, y| {
        for ([_]u32{0} ** WIDTH) |_| {
            var y_mapped = map(@intCast(y), 0, HEIGHT, 1, 255);
            // var _ = map(@intCast(x), 0, WIDTH, 1, 255);

            // std.debug.print("y {} x {} y_mapped {} x_mapped {}\n", .{ y, x, y_mapped, x_mapped });
            // var r = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intCast(255 / y_mapped))});
            // var g = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intCast(255 / x_mapped))});
            // var b = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intCast(255 / y_mapped))});
            var r = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intCast(y_mapped))});
            var g = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intCast(y_mapped))});
            var b = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intCast(y_mapped))});
            try write_str(image_buffer, r);
            try write_str(image_buffer, " ");
            try write_str(image_buffer, g);
            try write_str(image_buffer, " ");
            try write_str(image_buffer, b);
            try write_str(image_buffer, "\n");
        }
    }
}

fn write_file(image_buffer: *std.ArrayList(u8), filename: []const u8) !void {
    var file = try fs.cwd().openFile(filename, fs.File.OpenFlags{ .mode = .read_write });
    defer file.close();
    var writer = file.writer();
    try writer.writeAll(try image_buffer.toOwnedSlice());
}

fn process_filename_arg(filename: []const u8) !void {
    var file = std.fs.cwd().createFile(filename, .{ .exclusive = true }) catch |e|
        switch (e) {
        error.PathAlreadyExists => {
            return;
        },
        else => return e,
    };
    defer file.close();
}

pub fn main() !void {
    var image_buffer = std.ArrayList(u8).init(std.heap.page_allocator);

    defer image_buffer.deinit();
    var args = std.process.args();
    _ = args.skip();
    const filename = args.next();
    if (filename) |f| {
        try process_filename_arg(f);
        try write_str(&image_buffer, try std.fmt.allocPrint(std.heap.page_allocator, "P3\n{} {}\n255\n", .{ WIDTH, HEIGHT }));
        try render(&image_buffer);
        try write_file(&image_buffer, f);
    }
}
