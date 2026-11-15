import socket
from concurrent.futures import ThreadPoolExecutor


def query(requests):
    with socket.create_connection(("127.0.0.1", 4043), timeout=5) as connection:
        with connection.makefile("rb") as replies:
            for request in requests:
                connection.sendall((request + "\n").encode("ascii"))
                print(f"{request} -> {replies.readline().decode().strip()}")


with ThreadPoolExecutor(max_workers=2) as pool:
    first = pool.submit(query, ["PATH A D", "PATH A E"])
    second = pool.submit(query, ["PATH D A", "PATH X A"])
    first.result()
    second.result()
