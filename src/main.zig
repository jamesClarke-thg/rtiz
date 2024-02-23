const std = @import("std");
const fs = std.fs;
const ArrayList = std.ArrayList;

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
    const Self = @This();

    pub fn length(self: *Self) f32 {
        return @sqrt(self.length_squared());
    }

    pub fn length_squared(self: *const Self) f32 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn dot(first: Vec3, second: Vec3) f32 {
        return first.x * second.x + first.y * second.y + first.z * second.z;
    }

    pub fn cross(first: Vec3, second: Vec3) Vec3 {
        return Vec3{ .x = first.y * second.z - first.z * second.y, .y = first.z * second.x - first.x * second.z, .z = first.x * second.y - first.y * second.x };
    }

    pub fn add(self: *const Self, value: f32) Vec3 {
        return Vec3{ .x = self.x + value, .y = self.y + value, .z = self.z + value };
    }

    pub fn add_vec(self: *const Self, value: Vec3) Vec3 {
        return Vec3{ .x = self.x + value.x, .y = self.y + value.y, .z = self.z + value.z };
    }

    pub fn sub_vec(self: *const Self, value: Vec3) Vec3 {
        return self.add_vec(value.mul(-1));
    }

    pub fn mul_vec(self: *const Self, value: Vec3) Vec3 {
        return Vec3{ .x = self.x * value.x, .y = self.y * value.y, .z = self.z * value.z };
    }

    pub fn mul(self: *const Self, value: f32) Vec3 {
        return Vec3{ .x = self.x * value, .y = self.y * value, .z = self.z * value };
    }

    pub fn div(self: *const Self, value: f32) Vec3 {
        return self.mul(1 / value);
    }

    pub fn unit(self: *const Self) Vec3 {
        return self.div(self.length());
    }
};

const Ray = struct {
    origin: Vec3,
    direction: Vec3,
    const Self = @This();

    pub fn at(self: *Self, t: f32) Vec3 {
        return self.origin.add(self.direction.mul(t));
    }
};

// image settings
const WIDTH: u32 = 50;
const ASPECT_RATIO: f32 = 16.0 / 9.0;
const HEIGHT: u32 = @intFromFloat(WIDTH / ASPECT_RATIO);

// camera settings
const VIEWPORT_HEIGHT = 2.0;
const VIEWPORT_WIDTH = VIEWPORT_HEIGHT * @as(f32, @floatFromInt(WIDTH / HEIGHT));
const FOCAL_LENGTH = 1.0;
const CAMERA_CENTER = Vec3{ .x = 0, .y = 0, .z = 0 };

// camera/screen settings
// (assuming 1920x1080) we go from 0,0,0 to 1920, -1080, 0 because 0,0,0 is at the top left
const VIEWPORT_MAX_HORIZONTAL = Vec3{ .x = VIEWPORT_WIDTH, .y = 0, .z = 0 };
const VIEWPORT_MAX_VERTICAL = Vec3{ .x = 0, .y = -VIEWPORT_HEIGHT, .z = 0 };

// calculate the deltas vectors between each pixel
const VIEWPORT_HORIZONTAL_PIXEL_DELTA = VIEWPORT_MAX_HORIZONTAL.div(WIDTH);
const VIEWPORT_VERTICAL_PIXEL_DELTA = VIEWPORT_MAX_VERTICAL.div(HEIGHT);

// location of upper left pixel
const VIEWPORT_UPPER_LEFT = CAMERA_CENTER.sub_vec(Vec3{ .x = 0, .y = 0, .z = FOCAL_LENGTH }).sub_vec(VIEWPORT_MAX_HORIZONTAL.div(2)).sub_vec(VIEWPORT_MAX_VERTICAL.div(2));
const PIXEL_00_LOCATION = VIEWPORT_UPPER_LEFT.add(0.5).mul_vec(VIEWPORT_HORIZONTAL_PIXEL_DELTA.add_vec(VIEWPORT_VERTICAL_PIXEL_DELTA));

fn calculate_pixel_colour(ray: Ray) Vec3 {
    std.debug.print("{}", .{ray.origin.x});
    return Vec3{ .x = 0, .y = 0, .z = 0 };
}

fn write_colour(image_buffer: *std.ArrayList(u8), colour: Vec3) !void {
    var r = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intFromFloat(255.0 * colour.x))});
    var g = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intFromFloat(255.0 * colour.y))});
    var b = try std.fmt.allocPrint(std.heap.page_allocator, "{}", .{@as(u8, @intFromFloat(255.0 * colour.z))});
    try write_str(image_buffer, r);
    try write_str(image_buffer, g);
    try write_str(image_buffer, b);
    try write_str(image_buffer, "\n");
}

fn write_str(image_buffer: *std.ArrayList(u8), s: []const u8) !void {
    try image_buffer.appendSlice(s);
}

fn map(x: u32, in_min: u32, in_max: u32, out_min: u32, out_max: u32) u32 {
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

fn render(image_buffer: *std.ArrayList(u8)) !void {
    for ([_]u32{0} ** HEIGHT, 0..) |_, y| {
        for ([_]u32{0} ** WIDTH, 0..) |_, x| {

            // var pixel_center = pixel00_location
            var ray_direction = PIXEL_00_LOCATION.add_vec(VIEWPORT_HORIZONTAL_PIXEL_DELTA.mul(@floatFromInt(x))).add_vec(VIEWPORT_VERTICAL_PIXEL_DELTA.mul(@floatFromInt(y)));
            var ray = Ray{ .origin = CAMERA_CENTER, .direction = ray_direction };
            var pixel_colour = calculate_pixel_colour(ray);
            try write_colour(image_buffer, pixel_colour);
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
