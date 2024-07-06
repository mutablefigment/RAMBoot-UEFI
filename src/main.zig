const std = @import("std");
const uefi = std.os.uefi;

pub fn main() void {
    const con_out = uefi.system_table.con_out.?;
    const boot_services = uefi.system_table.boot_services.?;

    // Clear the screen
    _ = con_out.reset(false);

    // Print some text
    const L = std.unicode.utf8ToUtf16LeStringLiteral;
    _ = con_out.outputString(L("test\r\n"));

    // Wait 5 seconds
    _ = boot_services.stall(5 * 1000 * 1000);
}
