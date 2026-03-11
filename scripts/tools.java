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
     * Patch libCore.so to bypass the AIR commercial license check.
     *
     * The AIR runtime contains a function that prints
     * "Adobe AIR - Linux runtime is limited to use by commercially licensed
     * developers" and calls exit(0). We locate this function by searching for
     * a unique byte signature (push rbx; mov rbx,[rip+disp] loading stderr;
     * lea rdx,[rip+disp] loading the asterisk banner; mov esi,1; xor eax,eax)
     * and replace the first byte (0x53 push rbx) with 0xC3 (ret) so the
     * function returns immediately without printing or exiting.
     */
    private static void patchAirLicense(Path libCorePath) throws IOException {
        // Signature: push rbx / mov rbx,[rip+??] / lea rdx,[rip+??] / mov esi,1 / xor eax,eax
        // Bytes:     53 48 8b 1d ?? ?? ?? ?? 48 8d 15 ?? ?? ?? ?? be 01 00 00 00 31 c0
        // We match fixed bytes and skip wildcard positions (the RIP-relative displacements).
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
        int patternLen = 22; // total bytes in the window

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

        // Patch: replace push %rbx (0x53) with ret (0xC3)
        try (RandomAccessFile raf = new RandomAccessFile(libCorePath.toFile(), "rw")) {
            raf.seek(matchOffset);
            raf.writeByte(0xC3);
        }

        System.out.printf("Patched AIR license check at offset 0x%x in %s%n",
                matchOffset, libCorePath);
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
        System.err.println("  java scripts/tools.java patch-air-license <libCore.so>");
    }
}
