import java.nio.charset.StandardCharsets
import java.nio.file.Files
import java.nio.file.Paths

List<Map<String, List<StringBuilder>>> readLdif(List<String> lines) {
    def records = []
    def attributes = [:]
    StringBuilder previous = null
    lines.eachWithIndex { raw, index ->
        String line = index == 0 ? raw.replaceFirst(/^\uFEFF/, '') : raw
        if (line.isEmpty()) {
            if (attributes) records.add(attributes)
            attributes = [:]
            previous = null
        } else if (line.startsWith(' ')) {
            if (previous == null) throw new IllegalArgumentException("Line ${index + 1}: unexpected continuation")
            previous.append(line.substring(1))
        } else {
            def match = line =~ /^([A-Za-z][A-Za-z0-9-]*):(?![:<]) *(.*)$/
            if (!match.matches()) throw new IllegalArgumentException("Line ${index + 1}: expected name: value")
            String name = match.group(1).toLowerCase(Locale.ROOT)
            previous = new StringBuilder(match.group(2))
            attributes.computeIfAbsent(name) { [] }.add(previous)
        }
    }
    if (attributes) records.add(attributes)
    records
}

String escapeValue(String value) {
    value.replace('\\', '\\\\').replace(';', '\\;')
}

String csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\r') || value.contains('\n')) {
        return '"' + value.replace('"', '""') + '"'
    }
    value
}

String toCsv(List<Map<String, List<StringBuilder>>> records) {
    def names = new TreeSet<String>()
    records.each { names.addAll(it.keySet()) }
    names.remove('dn')
    def columns = ['dn'] + names.toList()
    def rows = [columns.collect { csvCell(it) }.join(',')]
    records.each { record ->
        rows.add(columns.collect { name ->
            def values = record[name] ?: []
            csvCell(values.collect { escapeValue(it.toString()) }.join(';'))
        }.join(','))
    }
    rows.join('\r\n') + '\r\n'
}

try {
    if (args.length != 2) throw new IllegalArgumentException('Usage: run.cmd [INPUT.ldif OUTPUT.csv]')
    def records = readLdif(Files.readAllLines(Paths.get(args[0]), StandardCharsets.UTF_8))
    def result = toCsv(records)
    Files.writeString(Paths.get(args[1]), result, StandardCharsets.UTF_8)
    print(result)
} catch (Exception err) {
    System.err.println('Error: ' + err.message)
    System.exit(1)
}
