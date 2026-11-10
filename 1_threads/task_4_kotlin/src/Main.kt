import java.io.File
import java.util.Locale
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import kotlin.math.sqrt

data class Table(val headers: List<String>, val rows: List<DoubleArray>)

fun csvFields(line: String): List<String> {
    val fields = mutableListOf<String>()
    val cell = StringBuilder()
    var quoted = false
    var closed = false
    var i = 0
    while (i < line.length) {
        val c = line[i]
        if (quoted) {
            if (c == '"') {
                if (i + 1 < line.length && line[i + 1] == '"') { cell.append('"'); i++ }
                else { quoted = false; closed = true }
            } else cell.append(c)
        } else when {
            c == ',' -> { fields.add(cell.toString()); cell.setLength(0); closed = false }
            c == '"' && cell.isEmpty() && !closed -> quoted = true
            closed && c.isWhitespace() -> Unit
            closed || c == '"' -> error("Invalid CSV quoting")
            else -> cell.append(c)
        }
        i++
    }
    require(!quoted) { "Unclosed CSV quote" }
    fields.add(cell.toString())
    return fields
}

fun readTable(path: String): Table {
    val lines = File(path).readLines().mapIndexed { i, s -> if (i == 0) s.removePrefix("\uFEFF") else s }
    require(lines.size >= 3) { "CSV needs a header and at least two observations" }
    val headers = csvFields(lines.first()).map { it.trim() }
    require(headers.all { it.isNotEmpty() } && headers.distinct().size == headers.size) { "Invalid headers" }
    val rows = lines.drop(1).mapIndexed { row, line ->
        val fields = csvFields(line)
        require(fields.size == headers.size) { "Wrong column count at row ${row + 2}" }
        fields.map { text ->
            val value = text.trim().toDoubleOrNull()
            require(value != null && value.isFinite()) { "Invalid number at row ${row + 2}" }
            value
        }.toDoubleArray()
    }
    return Table(headers, rows)
}

fun correlate(table: Table, threads: Int): Array<DoubleArray> {
    require(threads > 0)
    val n = table.rows.size
    val p = table.headers.size
    val means = DoubleArray(p) { j -> table.rows.sumOf { it[j] / n } }
    val deviations = Array(p) { j -> DoubleArray(n) { r -> table.rows[r][j] - means[j] } }
    val squares = DoubleArray(p) { j -> if (table.rows.all { it[j] == table.rows[0][j] }) 0.0 else deviations[j].sumOf { it * it } }
    require(squares.all { it.isFinite() }) { "Values are too large for Double arithmetic" }
    val matrix = Array(p) { DoubleArray(p) }
    val pool = Executors.newFixedThreadPool(threads)
    try {
        val jobs = (0 until p).flatMap { i -> (i until p).map { j ->
            Callable {
                val value = when {
                    squares[i] == 0.0 || squares[j] == 0.0 -> Double.NaN
                    i == j -> 1.0
                    else -> {
                        val covariance = (0 until n).sumOf { deviations[i][it] * deviations[j][it] }
                        val result = covariance / sqrt(squares[i]) / sqrt(squares[j])
                        require(result.isFinite()) { "Numerical overflow" }
                        result.coerceIn(-1.0, 1.0)
                    }
                }
                Triple(i, j, value)
            }
        } }
        for (future in pool.invokeAll(jobs)) {
            val (i, j, value) = future.get()
            matrix[i][j] = value
            matrix[j][i] = value
        }
    } finally { pool.shutdown() }
    return matrix
}

fun main(args: Array<String>) {
    try {
        val input = args.getOrElse(0) { "data/observations.csv" }
        val output = args.getOrElse(1) { "results/correlation.csv" }
        val threads = args.getOrElse(2) { "4" }.toInt()
        val table = readTable(input)
        val matrix = correlate(table, threads)
        fun quote(s: String) = "\"" + s.replace("\"", "\"\"") + "\""
        val lines = mutableListOf("feature," + table.headers.joinToString(",") { quote(it) })
        matrix.forEachIndexed { i, row ->
            lines.add(quote(table.headers[i]) + "," + row.joinToString(",") {
                if (it.isNaN()) "NaN" else String.format(Locale.US, "%.6f", it)
            })
        }
        File(output).absoluteFile.parentFile.mkdirs()
        File(output).writeText(lines.joinToString("\n") + "\n")
        println("Observations: ${table.rows.size}; features: ${table.headers.size}; threads: $threads")
        lines.forEach(::println)
        println("NaN = undefined correlation for a constant column")
        println("Saved to $output")
    } catch (e: Exception) {
        System.err.println("Error: ${e.message}")
        kotlin.system.exitProcess(1)
    }
}
