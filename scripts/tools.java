import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.Enumeration;
import java.util.List;
import java.util.stream.Collectors;
import java.util.zip.CRC32;
import java.util.zip.InflaterInputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipOutputStream;

public class tools {
    public static void main(String[] args) throws Exception {
        if (args.length == 0) {
            printUsage();
            System.exit(1);
        }

        switch (args[0]) {
            case "extract-library-swf":
                requireArgCount(args, 3);
                extractLibrarySwf(Path.of(args[1]), Path.of(args[2]));
                return;
            case "normalize-aab":
                requireArgCount(args, 3);
                normalizeAab(Path.of(args[1]), Path.of(args[2]));
                return;
            case "inspect-native-libs":
                requireArgCount(args, 2);
                inspectNativeLibs(Path.of(args[1]));
                return;
            case "patch-air-license":
                requireArgCount(args, 2);
                patchAirLicense(Path.of(args[1]));
                return;
            default:
                System.err.println("Unknown command: " + args[0]);
                printUsage();
                System.exit(1);
        }
    }

    private static void extractLibrarySwf(Path swcPath, Path outputPath) throws IOException {
        byte[] data;
        try (ZipFile zipFile = new ZipFile(swcPath.toFile())) {
            ZipEntry entry = zipFile.getEntry("library.swf");
            if (entry == null) {
                throw new IOException("Missing library.swf in " + swcPath);
            }

            try (InputStream input = zipFile.getInputStream(entry)) {
                data = input.readAllBytes();
            }
        }

        data = normalizeSwfCompression(data);
        createParentDirectories(outputPath);
        Files.write(outputPath, data);
    }

    private static byte[] normalizeSwfCompression(byte[] data) throws IOException {
        if (data.length < 8) {
            throw new IOException("Invalid SWF header");
        }

        if (data[0] != 'C' || data[1] != 'W' || data[2] != 'S') {
            return data;
        }

        byte[] body = inflate(data, 8);
        byte[] output = new byte[8 + body.length];
        output[0] = 'F';
        output[1] = 'W';
        output[2] = 'S';
        output[3] = data[3];
        System.arraycopy(data, 4, output, 4, 4);
        System.arraycopy(body, 0, output, 8, body.length);
        return output;
    }

    private static byte[] inflate(byte[] data, int offset) throws IOException {
        try (
                ByteArrayInputStream raw = new ByteArrayInputStream(data, offset, data.length - offset);
                InflaterInputStream inflater = new InflaterInputStream(raw);
                ByteArrayOutputStream output = new ByteArrayOutputStream()) {
            inflater.transferTo(output);
            return output.toByteArray();
        }
    }

    private static void normalizeAab(Path source, Path target) throws IOException {
        createParentDirectories(target);
        try (
                ZipFile zipFile = new ZipFile(source.toFile());
                ZipOutputStream output = new ZipOutputStream(Files.newOutputStream(target))) {
            Enumeration<? extends ZipEntry> entries = zipFile.entries();
            while (entries.hasMoreElements()) {
                ZipEntry inputEntry = entries.nextElement();
                byte[] data = readEntry(zipFile, inputEntry);
                ZipEntry outputEntry = new ZipEntry(inputEntry.getName());
                copyMetadata(inputEntry, outputEntry);

                int method = inputEntry.getName().endsWith(".so") ? ZipEntry.DEFLATED : inputEntry.getMethod();
                outputEntry.setMethod(method);
                if (method == ZipEntry.STORED) {
                    prepareStoredEntry(outputEntry, data);
                }

                output.putNextEntry(outputEntry);
                if (!inputEntry.isDirectory()) {
                    output.write(data);
                }
                output.closeEntry();
            }
        }
    }

    /**
     * Patch the AIR runtime binary to bypass the commercial license check.
     *
     * Supports both Linux (.so) and Windows (.dll) binaries. The AIR runtime
     * contains a function that prints a "commercially licensed developers"
     * warning and calls exit(0).
     *
     * For Linux (libCore.so): uses a known byte signature to locate the
     * function and replaces its first byte with 0xC3 (ret).
     *
     * For Windows (.dll): uses a string-search approach — locates the
     * "runtime is limited" warning string, finds a LEA instruction that
     * references it, walks backward to the function prologue, and patches
     * the first byte with 0xC3 (ret).
     */
    private static void patchAirLicense(Path binaryPath) throws IOException {
        String name = binaryPath.getFileName().toString().toLowerCase();
        if (name.endsWith(".dll")) {
            patchAirLicenseWindows(binaryPath);
        } else {
            patchAirLicenseLinux(binaryPath);
        }
    }

    /**
     * Linux-specific license patch using a known byte signature.
     * Signature: push rbx / mov rbx,[rip+??] / lea rdx,[rip+??] / mov esi,1 / xor eax,eax
     */
    private static void patchAirLicenseLinux(Path libCorePath) throws IOException {
        byte[] fixed  = { 0x53, 0x48, (byte)0x8b, 0x1d,
                          /*4-7: wildcard*/
                          0x48, (byte)0x8d, 0x15,
                          /*11-14: wildcard*/
                          (byte)0xbe, 0x01, 0x00, 0x00, 0x00,
                          0x31, (byte)0xc0 };
        int[] fixedIdx = { 0, 1, 2, 3,          // 53 48 8b 1d
                           8, 9, 10,             // 48 8d 15
                           15, 16, 17, 18, 19,   // be 01 00 00 00
                           20, 21 };             // 31 c0
        int patternLen = 22;

        byte[] data = Files.readAllBytes(libCorePath);

        int matchOffset = -1;
        for (int i = 0; i <= data.length - patternLen; i++) {
            boolean match = true;
            for (int fi = 0; fi < fixedIdx.length; fi++) {
                int pos = fixedIdx[fi];
                if (data[i + pos] != fixed[fi]) {
                    match = false;
                    break;
                }
            }
            if (match) {
                if (matchOffset != -1) {
                    throw new IOException(
                        "Multiple license-check signatures found (0x"
                        + Integer.toHexString(matchOffset) + " and 0x"
                        + Integer.toHexString(i) + "); aborting");
                }
                matchOffset = i;
            }
        }

        if (matchOffset == -1) {
            throw new IOException(
                "License-check signature not found in " + libCorePath
                + "; the AIR SDK version may have changed");
        }

        try (RandomAccessFile raf = new RandomAccessFile(libCorePath.toFile(), "rw")) {
            raf.seek(matchOffset);
            raf.writeByte(0xC3);
        }

        System.out.printf("Patched AIR license check at offset 0x%x in %s%n",
                matchOffset, libCorePath);
    }

    /**
     * Windows-specific license patch using string-search approach.
     *
     * 1. Find the "runtime is limited" ASCII string in the binary.
     * 2. Search for a LEA reg,[rip+disp32] instruction (48 8d XX YY YY YY YY)
     *    whose RIP-relative displacement resolves to the string offset.
     * 3. Walk backward from the LEA to find the function start, identified by
     *    int3 padding (0xCC bytes) that MSVC places between functions.
     * 4. Replace the first byte of the function with 0xC3 (ret).
     */
    private static void patchAirLicenseWindows(Path dllPath) throws IOException {
        byte[] data = Files.readAllBytes(dllPath);
        String marker = "runtime is limited";
        byte[] markerBytes = marker.getBytes(java.nio.charset.StandardCharsets.US_ASCII);

        // Step 1: Find the marker string in the binary
        int stringOffset = indexOf(data, markerBytes);
        if (stringOffset == -1) {
            System.out.println("License-check string \"" + marker + "\" not found in " + dllPath
                + "; HARMAN AIR SDK may not require this patch — skipping.");
            return;
        }
        System.out.printf("Found license string at offset 0x%x%n", stringOffset);

        // Step 2: Find a LEA instruction that references the string.
        // LEA with RIP-relative addressing: 48 8d [05|0d|15|1d|25|2d|35|3d] disp32
        // or without REX.W:                    8d [05|0d|15|1d|25|2d|35|3d] disp32
        // The displacement is computed as: stringOffset - (instrAddr + instrLen)
        int leaOffset = -1;
        for (int i = 0; i <= data.length - 7; i++) {
            boolean hasRex = (data[i] & 0xFF) == 0x48 || (data[i] & 0xFF) == 0x4C;
            int modrmIdx = hasRex ? i + 2 : i + 1;
            int opcodeIdx = hasRex ? i + 1 : i;

            if (modrmIdx + 5 > data.length) continue;
            if ((data[opcodeIdx] & 0xFF) != 0x8d) continue;

            int modrm = data[modrmIdx] & 0xFF;
            // mod=00, r/m=101 (RIP-relative): modrm & 0xC7 == 0x05
            if ((modrm & 0xC7) != 0x05) continue;

            int instrLen = hasRex ? 7 : 6;
            int dispOffset = modrmIdx + 1;
            int disp = (data[dispOffset] & 0xFF)
                     | ((data[dispOffset + 1] & 0xFF) << 8)
                     | ((data[dispOffset + 2] & 0xFF) << 16)
                     | ((data[dispOffset + 3] & 0xFF) << 24);
            int target = i + instrLen + disp;

            // Allow the LEA to point anywhere within a reasonable window
            // around the marker string (some compilers point to a banner
            // that contains the marker, not the exact start).
            if (target >= stringOffset - 256 && target <= stringOffset) {
                leaOffset = i;
                System.out.printf("Found LEA referencing license string at offset 0x%x (target 0x%x)%n",
                        leaOffset, target);
                break;
            }
        }

        if (leaOffset == -1) {
            throw new IOException(
                "Could not find LEA instruction referencing the license string in " + dllPath);
        }

        // Step 3: Walk backward to find the function start.
        // MSVC/PE typically pads between functions with 0xCC (int3) bytes.
        // We look for a run of CC bytes (at least 1) and take the byte
        // immediately after them as the function entry point.
        int funcStart = -1;
        for (int i = leaOffset - 1; i >= 1; i--) {
            if ((data[i] & 0xFF) == 0xCC) {
                // Found int3 padding; function starts at the next byte
                funcStart = i + 1;
                break;
            }
            // Also detect function boundary by ret (C3) or ret imm16 (C2 xx xx)
            if ((data[i] & 0xFF) == 0xC3) {
                funcStart = i + 1;
                break;
            }
            if (i >= 2 && (data[i - 2] & 0xFF) == 0xC2) {
                funcStart = i + 1;
                break;
            }
            // Safety limit: don't walk back more than 512 bytes
            if (leaOffset - i > 512) {
                break;
            }
        }

        if (funcStart == -1) {
            throw new IOException(
                "Could not locate function prologue before LEA at 0x"
                + Integer.toHexString(leaOffset) + " in " + dllPath);
        }

        // Sanity check: the function start should be before the LEA and
        // shouldn't already be a RET
        if ((data[funcStart] & 0xFF) == 0xC3) {
            System.out.printf("Function at 0x%x already patched (0xC3), skipping%n", funcStart);
            return;
        }

        System.out.printf("Function prologue at offset 0x%x (LEA at 0x%x, distance %d bytes)%n",
                funcStart, leaOffset, leaOffset - funcStart);

        // Step 4: Patch with RET
        try (RandomAccessFile raf = new RandomAccessFile(dllPath.toFile(), "rw")) {
            raf.seek(funcStart);
            raf.writeByte(0xC3);
        }

        System.out.printf("Patched AIR license check at offset 0x%x in %s%n",
                funcStart, dllPath);
    }

    /** Find the first occurrence of needle in haystack, or -1 if not found. */
    private static int indexOf(byte[] haystack, byte[] needle) {
        outer:
        for (int i = 0; i <= haystack.length - needle.length; i++) {
            for (int j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) continue outer;
            }
            return i;
        }
        return -1;
    }

    private static void inspectNativeLibs(Path archivePath) throws IOException {
        long sizeBytes = Files.size(archivePath);
        double sizeMiB = sizeBytes / (1024.0 * 1024.0);

        System.out.printf("APK: %s%n", archivePath);
        System.out.printf("Size: %.2f MiB%n", sizeMiB);

        try (ZipFile zipFile = new ZipFile(archivePath.toFile())) {
            List<? extends ZipEntry> libs = zipFile.stream()
                    .filter(entry -> !entry.isDirectory())
                    .filter(entry -> entry.getName().startsWith("lib/"))
                    .filter(entry -> entry.getName().endsWith(".so"))
                    .sorted(Comparator.comparingLong(ZipEntry::getSize).reversed())
                    .collect(Collectors.toList());

            for (ZipEntry entry : libs) {
                String method = entry.getMethod() == ZipEntry.STORED ? "STORED" : "DEFLATED";
                System.out.printf(
                        "%s: %s (%d/%d)%n",
                        entry.getName(),
                        method,
                        entry.getCompressedSize(),
                        entry.getSize());
            }
        }
    }

    private static byte[] readEntry(ZipFile zipFile, ZipEntry entry) throws IOException {
        if (entry.isDirectory()) {
            return new byte[0];
        }

        try (InputStream input = zipFile.getInputStream(entry)) {
            return input.readAllBytes();
        }
    }

    private static void copyMetadata(ZipEntry source, ZipEntry target) {
        long time = source.getTime();
        if (time != -1L) {
            target.setTime(time);
        }

        String comment = source.getComment();
        if (comment != null) {
            target.setComment(comment);
        }

        byte[] extra = source.getExtra();
        if (extra != null) {
            target.setExtra(extra);
        }
    }

    private static void prepareStoredEntry(ZipEntry entry, byte[] data) {
        CRC32 crc = new CRC32();
        crc.update(data);
        entry.setSize(data.length);
        entry.setCompressedSize(data.length);
        entry.setCrc(crc.getValue());
    }

    private static void createParentDirectories(Path path) throws IOException {
        Path parent = path.getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }
    }

    private static void requireArgCount(String[] args, int expected) {
        if (args.length != expected) {
            printUsage();
            System.exit(1);
        }
    }

    private static void printUsage() {
        System.err.println("Usage:");
        System.err.println("  java scripts/tools.java extract-library-swf <input.swc> <output.swf>");
        System.err.println("  java scripts/tools.java normalize-aab <input.aab> <output.aab>");
        System.err.println("  java scripts/tools.java inspect-native-libs <input.apk>");
        System.err.println("  java scripts/tools.java patch-air-license <libCore.so|Adobe AIR.dll>");
    }
}
