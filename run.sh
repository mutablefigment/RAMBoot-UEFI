#!/usr/bin/env bash
# This is a shell script which first builds the operating system and then runs it. 

# Using this command, we build the operating system, but at the command line we can specify 
# additional arguments to build the system with. 
zig build $@
# Here, we check that the exit code of the previous command is 0, so we ensure that the build 
# command succeeded. 
if [ $? -eq 0 ]; then
    # After that, we create the directory "systemroot/efi/boot" and all of its parent 
    # directories. 
    mkdir -p systemroot/efi/boot/
    # Now, we copy the bootloader executable to a folder that will be recognized by UEFI. 
    cp zig-out/bin/RAMBoot-UEFI.efi systemroot/efi/boot/bootx64.efi
    # Here, we copy the kernel executable to a custom location
    # cp zig-out/bin/kernel systemroot/kernel.elf
    # With this command, we start QEMU (a computer emulator) with UEFI as firmware (`-bios OVMF.fd`),
    # an emulated FAT drive with "systemroot" as directory and the standard output mapped to the COM1. 
    # Doing so will allow us to see messages from the operating system directly on our console. 
    qemu-system-x86_64 \
        -drive file=fat:rw:./systemroot,format=raw \
        -drive if=pflash,format=raw,readonly=on,file=$OVFM/OVMF_CODE.fd \
        -drive if=pflash,format=raw,file=./OVMF_VARS.fd \
        -serial mon:stdio \
        -display gtk \
        -s 
    # -bios $OVFM -hdd file=fat:rw:./systemroot/,id=fat32,format=raw,media=disk -serial mon:stdio -display gtk -s
fi