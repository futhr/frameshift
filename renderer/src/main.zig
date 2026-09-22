const std = @import("std");
const frameshift = @import("frameshift_raster");

pub fn main(init: std.process.Init) !void {
    var stdin_buffer: [8192]u8 = undefined;
    var stdin_reader: std.Io.File.Reader = .initStreaming(.stdin(), init.io, &stdin_buffer);
    var stdout_buffer: [8192]u8 = undefined;
    var stdout_writer: std.Io.File.Writer = .initStreaming(.stdout(), init.io, &stdout_buffer);

    try run(init.gpa, &stdin_reader.interface, &stdout_writer.interface);
    try stdout_writer.interface.flush();
}

fn run(
    allocator: std.mem.Allocator,
    reader: *std.Io.Reader,
    writer: *std.Io.Writer,
) !void {
    var prefix: [4]u8 = undefined;
    while (true) {
        const prefix_bytes = try reader.readSliceShort(&prefix);
        if (prefix_bytes == 0) return;
        if (prefix_bytes != prefix.len) {
            try frameshift.protocol.writeResponse(writer, .{ .status = .malformed });
            return;
        }

        const body_len = std.mem.readInt(u32, &prefix, .big);
        if (body_len > frameshift.protocol.max_frame_bytes) {
            try frameshift.protocol.writeResponse(writer, .{ .status = .bounds_exceeded });
            try writer.flush();
            return;
        }

        {
            const body = allocator.alloc(u8, body_len) catch {
                try frameshift.protocol.writeResponse(writer, .{ .status = .allocation_failed });
                try writer.flush();
                return;
            };
            defer allocator.free(body);

            reader.readSliceAll(body) catch {
                try frameshift.protocol.writeResponse(writer, .{ .status = .malformed });
                try writer.flush();
                return;
            };

            const response = frameshift.protocol.processFrame(allocator, body);
            defer if (response.status == .ok) allocator.free(response.payload);
            try frameshift.protocol.writeResponse(writer, response);
            try writer.flush();
        }
    }
}

test "empty input exits without a response" {
    var reader: std.Io.Reader = .fixed(&.{});
    var output: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&output);
    try run(std.testing.allocator, &reader, &writer);
    try std.testing.expectEqual(@as(usize, 0), writer.end);
}

test "oversized prefix returns a bounded error and stops" {
    var input: [4]u8 = undefined;
    std.mem.writeInt(u32, &input, frameshift.protocol.max_frame_bytes + 1, .big);
    var reader: std.Io.Reader = .fixed(&input);
    var output: [64]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&output);
    try run(std.testing.allocator, &reader, &writer);
    try std.testing.expectEqual(@as(u8, @intFromEnum(frameshift.protocol.Status.bounds_exceeded)), output[10]);
}
