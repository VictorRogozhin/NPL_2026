import java.nio.charset.StandardCharsets.UTF_8
import java.nio.file.{Files, Paths}
import java.util.Locale

object Main {
  case class Foreign(column: String, table: String, target: String)
  case class Table(name: String, columns: Vector[String], keys: Vector[Foreign])
  private val token = """(?s)--[^\r\n]*|/\*.*?\*/|'(?:''|[^'])*'|[A-Za-z0-9_]+|\S""".r
  private def upper(s: String): String = s.toUpperCase(Locale.ROOT)
  private def isName(s: String): Boolean = s.matches("[A-Za-z0-9_]+")

  def parse(sql: String): Vector[Table] = {
    val tokens = token.findAllIn(sql).filterNot(s => s.startsWith("--") || s.startsWith("/*")).buffered
    def pop(): String = {
      require(tokens.hasNext, "Unexpected end of SQL")
      tokens.next()
    }
    def expect(word: String): Unit = {
      val actual = pop()
      require(upper(actual) == word, s"Expected $word, got $actual")
    }
    val tables = Vector.newBuilder[Table]
    while (tokens.hasNext) {
      expect("CREATE")
      expect("TABLE")
      val name = pop()
      require(isName(name), "Invalid table name: " + name)
      expect("(")
      val clauses = Vector.newBuilder[Vector[String]]
      var clause = Vector.empty[String]
      var depth = 0
      while (!(tokens.hasNext && tokens.head == ")" && depth == 0)) {
        val part = pop()
        require(part != ";", "Unexpected semicolon inside " + name)
        if (part == "," && depth == 0) {
          clauses += clause
          clause = Vector.empty
        } else {
          clause :+= part
          if (part == "(") depth += 1
          if (part == ")") depth -= 1
        }
      }
      clauses += clause
      expect(")")
      if (tokens.hasNext && tokens.head == ";") pop()

      val columns = Vector.newBuilder[String]
      val primary = Vector.newBuilder[String]
      val foreign = Vector.newBuilder[Foreign]
      clauses.result().foreach { c =>
        c.map(upper) match {
          case Vector("FOREIGN", "KEY", "(", _, ")", "REFERENCES", _, "(", _, ")") =>
            require(Vector(c(3), c(6), c(8)).forall(isName), "Invalid foreign key in " + name)
            foreign += Foreign(c(3), c(6), c(8))
          case Vector("PRIMARY", "KEY", "(", rest @ _*) =>
            val keys = rest.dropRight(1)
            require(rest.lastOption.contains(")") && keys.nonEmpty && keys.length % 2 == 1 &&
              keys.zipWithIndex.forall { case (s, i) => if (i % 2 == 0) isName(s) else s == "," },
              "Invalid primary key in " + name)
            primary ++= c.slice(3, c.length - 1).filterNot(_ == ",")
          case _ =>
            require(c.length >= 2 && isName(c.head) && isName(c(1)) &&
              !Set("FOREIGN", "PRIMARY").contains(upper(c.head)), "Invalid column in " + name)
            columns += c.head
        }
      }
      val declared = columns.result()
      require(declared.nonEmpty && declared.distinct == declared, "Missing or duplicate columns in " + name)
      require(primary.result().forall(declared.contains), "Unknown primary key column in " + name)
      tables += Table(name, declared, foreign.result())
    }
    val result = tables.result()
    val byName = result.map(t => t.name -> t).toMap
    require(result.nonEmpty && byName.size == result.size, "Missing or duplicate tables")
    for (table <- result; key <- table.keys) {
      require(table.columns.contains(key.column), "Unknown column " + table.name + "." + key.column)
      require(byName.get(key.table).exists(_.columns.contains(key.target)),
        "Unknown reference " + key.table + "." + key.target)
    }
    result
  }

  def dot(tables: Vector[Table]): String = {
    def quoted(s: String): String = "\"" + s + "\""
    val nodes = tables.map(t => "  " + quoted(t.name) + ";")
    val edges = for (t <- tables; k <- t.keys) yield {
      val label = quoted(k.column + " -> " + k.target)
      "  " + quoted(t.name) + " -> " + quoted(k.table) + " [label=" + label + "];"
    }
    (Vector("digraph schema {") ++ nodes ++ edges ++ Vector("}", "")).mkString("\n")
  }

  def main(args: Array[String]): Unit = try {
    require(args.length == 2, "Usage: run.cmd [INPUT.sql OUTPUT.dot]")
    val tables = parse(Files.readString(Paths.get(args(0)), UTF_8).stripPrefix("\uFEFF"))
    val output = dot(tables)
    Files.writeString(Paths.get(args(1)), output, UTF_8)
    print(output)
  } catch {
    case scala.util.control.NonFatal(err) =>
      Console.err.println("Error: " + err.getMessage)
      sys.exit(1)
  }
}
