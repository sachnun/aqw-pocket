import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.FileVisitResult;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.SimpleFileVisitor;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.Stream;

public class patch {
    record Patch(String name, String find, String replace) {}

    public static void main(String[] args) throws Exception {
        clearAssetDir();
        downloadAsset();
        exportBytecode();
        List<Patch> patches = loadPatch(Paths.get("patches"));
        applyPatch(patches, Paths.get("assets", "Game-0"));
        build();
    }

    private static void clearAssetDir() throws IOException {
        Path assets = Paths.get("assets");
        if (Files.exists(assets)) {
            deleteRecursively(assets);
        }
        Files.createDirectory(assets);
    }

    private static void deleteRecursively(Path root) throws IOException {
        Files.walkFileTree(root, new SimpleFileVisitor<>() {
            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                Files.delete(file);
                return FileVisitResult.CONTINUE;
            }

            @Override
            public FileVisitResult postVisitDirectory(Path dir, IOException exc) throws IOException {
                if (exc != null) {
                    throw exc;
                }
                Files.delete(dir);
                return FileVisitResult.CONTINUE;
            }
        });
    }

    private static void downloadAsset() throws Exception {
        HttpClient client = HttpClient.newHttpClient();

        HttpRequest versionRequest = HttpRequest.newBuilder()
                .uri(URI.create("https://game.aq.com/game/api/data/gameversion"))
                .header("User-Agent", "Mozilla/5.0")
                .header("Accept", "application/json")
                .GET()
                .build();

        HttpResponse<String> versionResponse = client.send(versionRequest, HttpResponse.BodyHandlers.ofString());
        String gameFile = extractSFile(versionResponse.body());

        if (gameFile == null || gameFile.isEmpty()) {
            throw new IOException("Unable to parse sFile from game version response.");
        }

        System.out.println("Downloading: " + gameFile);

        HttpRequest gameRequest = HttpRequest.newBuilder()
                .uri(URI.create("https://game.aq.com/game/gamefiles/" + gameFile))
                .header("User-Agent", "Mozilla/5.0")
                .GET()
                .build();

        HttpResponse<byte[]> gameResponse = client.send(gameRequest, HttpResponse.BodyHandlers.ofByteArray());
        Files.write(Paths.get("assets", "Game.swf"), gameResponse.body());
    }

    private static String extractSFile(String json) {
        Pattern pattern = Pattern.compile("\"sFile\"\\s*:\\s*\"([^\"]+)\"");
        Matcher matcher = pattern.matcher(json);
        if (matcher.find()) {
            return matcher.group(1);
        }
        return null;
    }

    private static void exportBytecode() throws Exception {
        int abcexport = runCommand("abcexport", "assets/Game.swf");
        int rabcdasm = runCommand("rabcdasm", "assets/Game-0.abc");
        System.out.println("abcexport: " + abcexport + ", rabcdasm: " + rabcdasm);
    }

    private static void build() throws Exception {
        int rabcasm = runCommand("rabcasm", "assets/Game-0/Game-0.main.asasm");
        int abcreplace = runCommand("abcreplace", "assets/Game.swf", "0", "assets/Game-0/Game-0.main.abc");
        System.out.println("rabcasm: " + rabcasm + ", abcreplace: " + abcreplace);
    }

    private static int runCommand(String... command) throws Exception {
        Process process = new ProcessBuilder(command)
                .inheritIO()
                .start();
        int status = process.waitFor();
        if (status != 0) {
            throw new IOException("Command failed with status " + status + ": " + String.join(" ", command));
        }
        return status;
    }

    private static final String PATCH_SEPARATOR = "--- replace";

    private static List<Patch> loadPatch(Path path) throws IOException {
        List<Patch> patches = new ArrayList<>();
        if (!Files.exists(path)) {
            return patches;
        }

        try (Stream<Path> stream = Files.walk(path)) {
            List<Path> files = stream
                    .filter(Files::isRegularFile)
                    .filter(file -> file.toString().endsWith(".asasm"))
                    .sorted(Comparator.naturalOrder())
                    .collect(Collectors.toList());

            for (Path file : files) {
                String content = Files.readString(file, StandardCharsets.UTF_8);
                int separatorIndex = content.indexOf("\n" + PATCH_SEPARATOR + "\n");
                if (separatorIndex == -1) {
                    System.out.println("Skipping (no separator): " + file);
                    continue;
                }

                String findContent = content.substring(0, separatorIndex);
                String replaceContent = content.substring(separatorIndex + PATCH_SEPARATOR.length() + 2);

                if (findContent.isEmpty()) {
                    continue;
                }

                String name = path.relativize(file).toString();
                patches.add(new Patch(name, findContent, replaceContent));
            }
        }

        System.out.println("Loaded " + patches.size() + " patches");
        return patches;
    }

    private static void applyPatch(List<Patch> patches, Path path) throws IOException {
        if (!Files.exists(path)) {
            return;
        }

        Set<String> matched = new HashSet<>();

        try (Stream<Path> stream = Files.walk(path)) {
            List<Path> files = stream
                    .filter(Files::isRegularFile)
                    .filter(file -> file.toString().endsWith(".asasm"))
                    .collect(Collectors.toList());

            for (Path file : files) {
                String content = Files.readString(file, StandardCharsets.UTF_8);

                for (Patch patch : patches) {
                    String findNormalized = normalize(patch.find());
                    String contentNormalized = normalize(content);

                    if (!contentNormalized.contains(findNormalized)) {
                        continue;
                    }

                    List<String> blocks = findAllOriginalBlocks(content, findNormalized);
                    if (blocks.isEmpty()) {
                        continue;
                    }

                    matched.add(patch.name());
                    System.out.println("Applying " + patch.name() + " -> " + file);
                    for (String original : blocks) {
                        content = content.replaceFirst(Pattern.quote(original), Matcher.quoteReplacement(patch.replace()));
                    }

                    Files.writeString(file, content, StandardCharsets.UTF_8);
                }
            }
        }

        for (Patch patch : patches) {
            if (!matched.contains(patch.name())) {
                System.out.println("UNMATCHED: " + patch.name());
            }
        }
    }

    private static String normalize(String text) {
        return text.lines()
                .map(String::trim)
                .filter(line -> !line.isEmpty())
                .collect(Collectors.joining("\n"));
    }

    private static List<String> findAllOriginalBlocks(String content, String findNormalized) {
        String[] findLines = findNormalized.split("\\R");
        String[] contentLines = content.split("\\R", -1);
        List<String> results = new ArrayList<>();

        int ci = 0;
        outer:
        while (ci < contentLines.length) {
            int fi = 0;
            Integer start = null;
            int tmpCi = ci;

            while (tmpCi < contentLines.length) {
                String cl = contentLines[tmpCi].trim();

                if (cl.isEmpty()) {
                    tmpCi += 1;
                    continue;
                }

                if (cl.equals(findLines[fi])) {
                    if (fi == 0) {
                        start = tmpCi;
                    }
                    fi += 1;
                    tmpCi += 1;

                    if (fi == findLines.length) {
                        String block = String.join("\n", java.util.Arrays.copyOfRange(contentLines, start, tmpCi));
                        results.add(block);
                        ci = start + 1;
                        continue outer;
                    }
                } else {
                    break;
                }
            }

            ci += 1;
        }

        return results;
    }
}
