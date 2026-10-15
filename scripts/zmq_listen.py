#!/usr/bin/env python3
"""Escucha el topic ZMQ `sequence` de Bitcoin Core e imprime cada evento.

Uso (dentro de un contenedor del lab):
    python3 /lab/scripts/zmq_listen.py [tcp://127.0.0.1:28332]

Formato del mensaje (doc/zmq.md de Bitcoin Core):
    topic = b"sequence"
    body  = <hash de 32 bytes> + <etiqueta de 1 byte> [+ mempool sequence, uint64 LE]
    seq   = contador de mensajes del topic (uint32 LE)

El hash ya viene en el orden en que se muestra (igual que getrawmempool o un
explorador), así que se imprime sin invertir los bytes.
"""
import struct
import sys
import time

import zmq

LABELS = {
    "C": "bloque conectado",
    "D": "bloque desconectado",
    "A": "tx agregada al mempool",
    "R": "tx removida del mempool (no por entrar en un bloque)",
}

address = sys.argv[1] if len(sys.argv) > 1 else "tcp://127.0.0.1:28332"

socket = zmq.Context().socket(zmq.SUB)
socket.connect(address)
socket.setsockopt_string(zmq.SUBSCRIBE, "sequence")
print(f"Escuchando 'sequence' en {address} (Ctrl-C para salir)", flush=True)

try:
    while True:
        topic, body, _ = socket.recv_multipart()
        hash_hex = body[:32].hex()
        label = chr(body[32])
        line = f"{time.strftime('%H:%M:%S')}  {label}  {hash_hex}  {LABELS.get(label, '?')}"
        if label in ("A", "R"):
            (mempool_seq,) = struct.unpack("<Q", body[33:41])
            line += f"  (mempool seq {mempool_seq})"
        print(line, flush=True)
except KeyboardInterrupt:
    pass
