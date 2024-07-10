//https://chatgpt.com/c/e25f24f3-32be-436f-b15e-c42690ff06a4

const std = @import("std");
const uefi = std.os.uefi;
const log = std.log.scoped(.main);

var con_out: *uefi.protocol.SimpleTextOutput = undefined;

var already_called_puts: u8 = 0;

/// Put out any string
///   - msg: the string to put out
pub fn puts(msg: []const u8) void {
    if (already_called_puts == 0) {
        con_out = uefi.system_table.con_out.?;
        _ = con_out.reset(false);
        already_called_puts = 1;
    }
    for (msg) |c| {
        const c_ = [1:0]u16{c};
        _ = con_out.outputString(&c_);
    }
}

/// Put out any formatted string
pub fn printf(comptime fmt: []const u8, args: anytype) void {
    var buf: [256]u8 = undefined;
    var msg: []u8 = undefined;
    msg = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    puts(msg);
}

/// Standard Library Options
pub const std_options = .{
    .log_level = .debug,
    .logFn = logFn,
};

// Logging Function
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const color = comptime switch (level) {
        .debug => "\x1b[32m",
        .info => "\x1b[36m",
        .warn => "\x1b[33m",
        .err => "\x1b[31m",
    };
    const scope_prefix = "(" ++ @tagName(scope) ++ "): ";
    const prefix = "[" ++ color ++ comptime level.asText() ++ "\x1b[0m] " ++ scope_prefix;
    printf(prefix ++ format ++ "\r\n", args);
}

fn allocate_memory(boot_services: *uefi.tables.BootServices, size: usize) ?[*]u8 {
    var memory: ?[*]u8 = null;
    const memptr = @as(*[*]align(8) u8, @ptrCast(&memory));
    if (boot_services.allocatePool(uefi.tables.MemoryType.LoaderData, size, memptr) == uefi.Status.Success) {
        return memory;
    }
    return null;
}

pub fn main() void {
    con_out = uefi.system_table.con_out.?;
    const boot_services = uefi.system_table.boot_services.?;

    // Clear the screen
    _ = con_out.reset(false);

    // Print some text
    puts("Hello world!\r\n");

    // const L = std.unicode.utf8ToUtf16LeStringLiteral;
    // const kernel_path = L("\\OneFileLinux.efi");

    var file_system: *uefi.protocol.SimpleFileSystem = undefined;
    if (boot_services.locateProtocol(&uefi.protocol.SimpleFileSystem.guid, null, @ptrCast(&file_system)) != uefi.Status.Success) {
        puts("Failed finding fs handle!\r\n");
    }

    var root_fs_volume: *uefi.protocol.File = undefined;
    if (file_system.openVolume(&root_fs_volume) != uefi.Status.Success) {
        puts("Failed opening root volume!!\r\n");
        return;
    }

    var memory_map: [*]uefi.tables.MemoryDescriptor = undefined;
    var memory_map_size: usize = 0;
    var memory_map_key: usize = 0;
    var descriptor_size: usize = undefined;
    var descriptor_version: u32 = undefined;

    while (boot_services.getMemoryMap(&memory_map_size, memory_map, &memory_map_key, &descriptor_size, &descriptor_version) == .BufferTooSmall) {
        if (boot_services.allocatePool(.BootServicesData, memory_map_size, @ptrCast(@alignCast(&memory_map))) != uefi.Status.Success) {
            puts("Getting mem map failed!\r\n");
        }
    }

    // we allocate some memory
    var mem_index: usize = 0;
    var mem_count: usize = undefined;
    var mem_point: *uefi.tables.MemoryDescriptor = undefined;
    var base_address: u64 = 0x100000;
    var num_pages: usize = 0;
    mem_count = memory_map_size / descriptor_size;
    log.debug("mem_count is {}", .{mem_count});
    while (mem_index < mem_count) : (mem_index += 1) {
        log.debug("mem_index is {}", .{mem_index});
        mem_point = @ptrFromInt(@intFromPtr(memory_map) + (mem_index * descriptor_size));
        if (mem_point.type == .ConventionalMemory and mem_point.physical_start >= base_address) {
            base_address = mem_point.physical_start;
            num_pages = mem_point.number_of_pages;
            log.debug("Found {} free pages at 0x{x}", .{ num_pages, base_address });
            break;
        }
    }

    const kernel_path: [*:0]const u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\OneFileLinux.efi");

    var kernel_handle: *uefi.protocol.File = undefined;

    // load efi image
    if (root_fs_volume.open(&kernel_handle, kernel_path, uefi.protocol.File.efi_file_mode_read, uefi.protocol.File.efi_file_read_only) != uefi.Status.Success) {
        log.debug("Failed to open kernel image!", .{});
    }
    defer _ = kernel_handle.close();
    // const parent_handle: uefi.Handle = undefined;
    // boot_services.loadImage(true, parent_handle, null, null, 10, kernel_handle);
    // _ = boot_services.startImage(kernel_handle, null, null);

    // // Dark magic, remember this one lol
    // // FIXME: this will crash the system lol because it points to an empty memory region
    // const entry_point = @as(*const fn () void, @ptrCast(base_address));
    // const entry_point = @as(*const fn () void, @ptrFromInt(base_address));
    // entry_point();

    // Wait 5 seconds
    _ = boot_services.stall(5 * 1000 * 1000);
    while (true) {}
}
