import core.thread : Thread;
import std.algorithm : sort;
import std.array : join, split;
import std.bigint : BigInt;
import std.conv : to;
import std.exception : enforce;
import std.socket;
import std.stdio : File, stderr, writeln;
import std.string : strip;

struct Edge {
    size_t target;
    BigInt weight;
}

class Graph {
    string[] names;
    size_t[string] id;
    Edge[][] outgoing;

    this(string filename) {
        auto input = File(filename);
        enforce(!input.eof, "Missing vertex list");
        names = input.readln.strip.split;
        enforce(names.length > 0, "Missing vertex list");
        names.sort;
        outgoing.length = names.length;
        foreach (i, name; names) {
            enforce(name !in id, "Duplicate vertex");
            id[name] = i;
        }
        foreach (line; input.byLine) {
            auto fields = line.strip.split;
            if (fields.length == 0) continue;
            enforce(fields.length == 3, "Expected: from to weight");
            auto from = fields[0].idup in id;
            auto target = fields[1].idup in id;
            enforce(from && target, "Unknown vertex in graph");
            enforce(fields[2].length > 0, "Missing weight");
            foreach (digit; fields[2])
                enforce(digit >= '0' && digit <= '9', "Expected nonnegative integer weight");
            outgoing[*from] ~= Edge(*target, BigInt(fields[2]));
        }
    }

    string route(string start, string finish) {
        auto source = start in id;
        auto goal = finish in id;
        if (!source || !goal) return "ERR unknown vertex";
        const n = names.length;
        auto distance = new BigInt[n];
        auto previous = new size_t[n];
        auto known = new bool[n];
        auto settled = new bool[n];
        known[*source] = true;
        while (true) {
            size_t current = n;
            // Names are sorted, so equal distances settle by vertex name.
            foreach (i; 0 .. n)
                if (known[i] && !settled[i] && (current == n || distance[i] < distance[current]))
                    current = i;
            if (current == n) return "NO PATH";
            if (current == *goal) break;
            settled[current] = true;
            foreach (edge; outgoing[current]) {
                if (settled[edge.target]) continue;
                const candidate = distance[current] + edge.weight;
                if (!known[edge.target] || candidate < distance[edge.target]) {
                    distance[edge.target] = candidate;
                    previous[edge.target] = current;
                    known[edge.target] = true;
                }
            }
        }
        string[] path;
        for (size_t i = *goal;; i = previous[i]) {
            path ~= names[i];
            if (i == *source) break;
        }
        import std.algorithm : reverse;
        path.reverse;
        return "OK " ~ distance[*goal].to!string ~ " " ~ path.join(" ");
    }
}

void sendAll(Socket socket, string message) {
    while (message.length > 0) {
        auto sent = socket.send(message);
        enforce(sent > 0, "Socket write failed");
        message = message[sent .. $];
    }
}

void serve(Socket socket, Graph graph) {
    scope(exit) socket.close();
    char[1024] buffer;
    char[] line;
    while (true) {
        auto count = socket.receive(buffer[]);
        if (count <= 0) return;
        foreach (ch; buffer[0 .. count]) {
            if (ch == '\n') {
                auto fields = line.idup.strip.split;
                string reply = "ERR expected PATH start finish";
                if (fields.length == 3 && fields[0] == "PATH")
                    reply = graph.route(fields[1], fields[2]);
                sendAll(socket, reply ~ "\n");
                line.length = 0;
            } else {
                if (line.length == 4096) {
                    sendAll(socket, "ERR request too long\n");
                    return;
                }
                line ~= ch;
            }
        }
    }
}

void handleClient(Socket client, Graph graph) {
    new Thread({
        try {
            serve(client, graph);
        } catch (Exception error) {
            stderr.writeln("Client disconnected: ", error.msg);
        }
    }).start();
}

int main(string[] args) {
    try {
        enforce(args.length <= 3, "Usage: routes [graph.txt] [port]");
        auto graph = new Graph(args.length >= 2 ? args[1] : "data/graph.txt");
        const port = args.length == 3 ? args[2].to!ushort : 4043;
        auto listener = new TcpSocket;
        scope(exit) listener.close();
        listener.bind(new InternetAddress("127.0.0.1", port));
        listener.listen(16);
        writeln("Listening on 127.0.0.1:", port);
        import std.stdio : stdout;
        stdout.flush();
        while (true) handleClient(listener.accept(), graph);
    } catch (Exception error) {
        stderr.writeln("Error: ", error.msg);
        return 1;
    }
}
