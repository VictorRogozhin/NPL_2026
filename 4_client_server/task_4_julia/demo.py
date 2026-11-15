from contextlib import ExitStack
from socket import create_connection


with ExitStack() as stack:
    def connect():
        sock = stack.enter_context(create_connection(("127.0.0.1", 4044), timeout=10))
        return sock, stack.enter_context(sock.makefile("rb"))

    def send(client, command):
        sock, replies = client
        sock.sendall((command + "\n").encode("ascii"))
        reply = replies.readline().decode().rstrip()
        print(f"{command} -> {reply}")

    alice, bob = connect(), connect()
    send(alice, "JOIN Alice")
    send(bob, "JOIN Bob")
    send(bob, "WORD orange")
    send(alice, "WORD Apple")
    send(bob, "WORD apple")
    send(bob, "WORD banana")
    send(bob, "WORD e123")
    send(bob, "WORD EAGLE")
    send(alice, "WORD earth")
