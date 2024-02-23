const std = @import("std");
const fs = std.fs;
const ArrayList = std.ArrayList;

const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,
    const Self = @This();

    pub fn length(self: *const Self) f32 {
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

    pub fn sub(self: *const Self, value: f32) Vec3 {
        return Vec3{ .x = self.x - value, .y = self.y - value, .z = self.z - value };
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

    pub fn pretty_print(self: *const Self) ![]u8 {
        return try std.fmt.allocPrint(std.heap.page_allocator, "{d} {d} {d}", .{ self.x, self.y, self.z });
    }
};

const Ray = struct {
    origin: Vec3,
    direction: Vec3,
    const Self = @This();

    pub fn at(self: *const Self, t: f32) Vec3 {
        return self.origin.add_vec(self.direction.mul(t));
    }
};

// 4k width = 3840
// 2k width = 2048
// image settings
const WIDTH: u32 = 3840;
const ASPECT_RATIO: f32 = 16.0 / 9.0;
const HEIGHT: u32 = @intFromFloat(WIDTH / ASPECT_RATIO);

// camera settings
const FOCAL_LENGTH = 1.0;
const VIEWPORT_HEIGHT = 2.0;
const VIEWPORT_WIDTH = VIEWPORT_HEIGHT * (@as(f32, @floatFromInt(WIDTH / HEIGHT)));
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
// const PIXEL_00_LOCATION = VIEWPORT_UPPER_LEFT.add(0.5).mul_vec(VIEWPORT_HORIZONTAL_PIXEL_DELTA.add_vec(VIEWPORT_VERTICAL_PIXEL_DELTA));
const PIXEL_00_LOCATION = ((VIEWPORT_HORIZONTAL_PIXEL_DELTA.add_vec(VIEWPORT_VERTICAL_PIXEL_DELTA)).mul(0.5)).add_vec(VIEWPORT_UPPER_LEFT);

fn hit_sphere(center: Vec3, radius: f32, ray: Ray) !f32 {
    // std.debug.print("checking if hit sphere, ray:\n", .{});
    // ray.direction.pretty_print();

    const origin_to_center = ray.origin.sub_vec(center);
    // std.debug.print("origin_to_center {s}\n", .{try origin_to_center.pretty_print()});
    const a = Vec3.dot(ray.direction, ray.direction);
    const b = 2 * Vec3.dot(origin_to_center, ray.direction);
    const c = Vec3.dot(origin_to_center, origin_to_center) - (radius * radius);
    const discriminant = b * b - 4 * a * c;
    // std.debug.print("discriminant {d}\n", .{discriminant});
    // return discriminant >= 0;

    if (discriminant < 0) {
        return -1.0;
    } else {
        return (-b - @sqrt(discriminant)) / (2.0 * a);
    }
}

fn calculate_pixel_colour(ray: Ray) !Vec3 {
    var t = try hit_sphere(Vec3{ .x = 0, .y = 0, .z = -3 }, 0.5, ray);
    if (t > 0.0) {
        var n = ray.at(t).sub_vec(Vec3{ .x = 0, .y = 0, .z = -1 }).unit();
        var c = Vec3{ .x = n.x + 1, .y = n.y + 1, .z = n.z + 1 };
        return c.mul(0.5);
    }
    var t_again = try hit_sphere(Vec3{ .x = 2, .y = 1, .z = -8 }, 3, ray);
    if (t_again > 0.0) {
        var n = ray.at(t).sub_vec(Vec3{ .x = 0, .y = 0, .z = -1 }).unit();
        var c = Vec3{ .x = n.x + 1, .y = n.y + 1, .z = n.z + 1 };
        return c.mul(0.5);
    }
    const unit_direction = ray.direction.unit();
    const a = 0.5 * (unit_direction.y + 1);
    const WHITE = Vec3{ .x = 1, .y = 1, .z = 1 };
    const BLUE = Vec3{ .x = 0.5, .y = 0.7, .z = 1.0 };
    return WHITE.mul(1.0 - a).add_vec(BLUE.mul(a));
}

fn write_colour(image_buffer: *std.ArrayList(u8), colour: Vec3) !void {
    var r = try std.fmt.allocPrint(std.heap.page_allocator, "{} ", .{@as(u8, @intFromFloat(255.0 * colour.x))});
    var g = try std.fmt.allocPrint(std.heap.page_allocator, "{} ", .{@as(u8, @intFromFloat(255.0 * colour.y))});
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
        std.debug.print("doing row {}/{}\n", .{ y, HEIGHT });
        for ([_]u32{0} ** WIDTH, 0..) |_, x| {
            // todo this is probably not correct but it works
            var y_vec = VIEWPORT_VERTICAL_PIXEL_DELTA.mul(@as(f32, @floatFromInt(y)) / ASPECT_RATIO + ((WIDTH - HEIGHT) / ASPECT_RATIO / 2));
            var pixel_center = PIXEL_00_LOCATION.add_vec(VIEWPORT_HORIZONTAL_PIXEL_DELTA.mul(@floatFromInt(x))).add_vec(y_vec);
            var ray_direction = pixel_center.sub_vec(CAMERA_CENTER);
            var ray = Ray{ .origin = CAMERA_CENTER, .direction = ray_direction };
            var pixel_colour = try calculate_pixel_colour(ray);
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
    std.debug.print("VIEWPORT_HEIGHT {d}\n", .{VIEWPORT_HEIGHT});
    std.debug.print("VIEWPORT_WIDTH {d}\n", .{VIEWPORT_WIDTH});
    std.debug.print("VIEWPORT_WIDTH {d}\n", .{FOCAL_LENGTH});
    std.debug.print("CAMERA_CENTER {s}\n", .{try CAMERA_CENTER.pretty_print()});
    std.debug.print("VIEWPORT_MAX_HORIZONTAL {s}\n", .{try VIEWPORT_MAX_HORIZONTAL.pretty_print()});
    std.debug.print("VIEWPORT_MAX_VERTICAL {s}\n", .{try VIEWPORT_MAX_VERTICAL.pretty_print()});
    std.debug.print("VIEWPORT_HORIZONTAL_PIXEL_DELTA {s}\n", .{try VIEWPORT_HORIZONTAL_PIXEL_DELTA.pretty_print()});
    std.debug.print("VIEWPORT_VERTICAL_PIXEL_DELTA {s}\n", .{try VIEWPORT_VERTICAL_PIXEL_DELTA.pretty_print()});
    std.debug.print("VIEWPORT_UPPER_LEFT {s}\n", .{try VIEWPORT_UPPER_LEFT.pretty_print()});
    std.debug.print("PIXEL_00_LOCATION {s}\n", .{try PIXEL_00_LOCATION.pretty_print()});

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
