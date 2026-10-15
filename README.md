# Vamos a mirar Bitcoin desde dentro de un nodo — lab

Material del workshop de LABITCONF 2026. Levantás **tres nodos Bitcoin Core 31.1** en tu máquina, en **regtest**: una blockchain de juguete donde vos minás los bloques cuando querés. No necesitás bajar la blockchain real ni tener bitcoin.

👉 **La guía paso a paso está en [guischet.xyz/workshops/bitcoin-inside-a-node](https://guischet.xyz/workshops/bitcoin-inside-a-node).** Este README solo te deja el lab andando.

```text
alice ──► bob ──► carol      (la flecha indica quién inicia la conexión)
```

## Empezá acá (5 pasos)

**0. Comprobá que tenés Docker.** Tiene que imprimir una versión 2.x. Si no la tenés, instalá [Docker](https://docs.docker.com/get-started/get-docker/). En Windows, usá la terminal de WSL2.

```bash
docker compose version
```

**1. Bajá el lab.**

```bash
git clone https://github.com/GuiSchet/bitcoin-inside-a-node-lab
cd bitcoin-inside-a-node-lab
```

**2. Levantá los tres nodos.** La primera vez tarda ~1 minuto: descarga Bitcoin Core de bitcoincore.org y verifica su hash.

```bash
docker compose up -d --wait
```

**3. Cargá los atajos y prepará el lab.** `source lab.sh` crea los comandos `alice`, `bob` y `carol`. `lab_setup` crea una wallet en cada nodo y mina 101 bloques para alice.

```bash
source lab.sh
lab_setup
```

Vas a ver: `Listo: alice tiene 50.00000000 BTC; los tres nodos están en el bloque 101.`

**4. Hacé tu primera pregunta al nodo.**

```bash
alice getblockchaininfo
```

`alice <comando>` es lo mismo que `docker compose exec -T alice bitcoin-cli <comando>`: le mandás un comando RPC al nodo de alice.

Listo. Ahora seguí con la guía.

## La guía, track por track

| Track | Qué vas a hacer | Nivel |
|---|---|---|
| [0. Preparación](https://guischet.xyz/workshops/bitcoin-inside-a-node/preparacion) | Lo mismo que arriba, explicado | Primera vez |
| [1. La foto](https://guischet.xyz/workshops/bitcoin-inside-a-node/la-foto) | Preguntarle al nodo dónde está, con quién habla y qué hay en su mempool | Primera vez |
| [2. Los logs](https://guischet.xyz/workshops/bitcoin-inside-a-node/los-logs) | Encender el log y ver a dos nodos pasarse una transacción | Primera vez |
| [3. La película](https://guischet.xyz/workshops/bitcoin-inside-a-node/la-pelicula) | Escuchar los eventos del nodo con ZMQ y ver una tx reemplazada (RBF) | Intermedio |
| [4. La conversación](https://guischet.xyz/workshops/bitcoin-inside-a-node/la-conversacion) | Ver los mensajes P2P y fabricar tu propio fork | Intermedio |
| [5. Más allá](https://guischet.xyz/workshops/bitcoin-inside-a-node/mas-alla) | Tracepoints, peer-observer y c12d | Lectura, sin ejercicios |

## Cinco palabras

- **Nodo**: un programa (acá, Bitcoin Core) que guarda la blockchain, valida todo y habla con otros nodos.
- **Regtest**: una red de prueba local. Los bloques se minan con un comando y las monedas no valen nada.
- **RPC**: la forma de hacerle preguntas al nodo. `bitcoin-cli` es el cliente.
- **Mempool**: la sala de espera de las transacciones que todavía no entraron en un bloque.
- **Peer**: otro nodo con el que el tuyo está conectado.

## Si algo falla

- **`Cannot connect to the Docker daemon`**: Docker no está corriendo. Abrilo y repetí el paso 2.
- **`alice: command not found`**: cada terminal nueva necesita `source lab.sh`, desde la carpeta del repo.
- **Querés empezar de cero**: `docker compose down -v` borra la blockchain regtest y las wallets. Después volvé al paso 2.

## Qué hay en el repo

| Archivo | Para qué |
|---|---|
| `Dockerfile` | Descarga Bitcoin Core 31.1 de bitcoincore.org y verifica su SHA256 |
| `docker-compose.yml` | Los tres nodos y sus conexiones |
| `conf/bitcoin.conf` | Configuración común: regtest, fallbackfee, ZMQ |
| `lab.sh` | Atajos: `alice`/`bob`/`carol`, `lab_setup`, `lab_split`, `lab_join`, `lab_wait_tx`, `lab_wait_sync` |
| `scripts/zmq_listen.py` | Escucha el topic ZMQ `sequence` e imprime cada evento |
| `tests/smoke.sh` | Corre todos los ejercicios desde cero y verifica cada resultado |
