#!/usr/bin/env bash
# Corre, desde cero, los ejercicios de todos los tracks y verifica que cada
# afirmación de la guía se cumple. Usar antes de cada presentación:
#
#   ./tests/smoke.sh
#
# Requiere Docker y jq. Borra el estado del lab (docker compose down -v).
set -euo pipefail
cd "$(dirname "$0")/.."
source lab.sh

pass() { echo "  ✅ $*"; }
fail() { echo "  ❌ $*" >&2; exit 1; }
check() { local desc=$1; shift; if "$@"; then pass "$desc"; else fail "$desc"; fi; }

echo "== Arranque limpio"
docker compose down -v -t 30 >/dev/null 2>&1 || true
docker compose up -d --wait >/dev/null 2>&1
sleep 3
check "alice tiene 1 peer, bob 2, carol 1" \
  test "$(alice getconnectioncount)$(bob getconnectioncount)$(carol getconnectioncount)" = "121"
check "versión 31.1" bash -c 'source lab.sh; alice getnetworkinfo | jq -e ".subversion == \"/Satoshi:31.1.0/\"" >/dev/null'

echo "== Track 1: la foto (RPC)"
check "getblockchaininfo: chain=regtest" bash -c 'source lab.sh; alice getblockchaininfo | jq -e ".chain == \"regtest\"" >/dev/null'
check "-netinfo 4 lista a bob como manual saliente" bash -c 'source lab.sh; alice -netinfo 4 | grep -E "^out +manual .* bob:18444" >/dev/null'
check "getpeerinfo: connection_type=manual, network=not_publicly_routable, v2" bash -c '
  source lab.sh; alice getpeerinfo | jq -e ".[0] | .connection_type == \"manual\" and .network == \"not_publicly_routable\" and .transport_protocol_type == \"v2\"" >/dev/null'
lab_setup >/dev/null
check "lab_setup: 101 bloques en los tres nodos" test "$(carol getblockcount)" = 101
check "alice tiene 50 BTC gastables" bash -c 'source lab.sh; test "$(alice getbalance)" = "50.00000000"'
check "lab_setup se puede correr dos veces" bash -c 'source lab.sh; lab_setup >/dev/null && test "$(carol getblockcount)" = 101'
TX=$(alice sendtoaddress "$(carol getnewaddress)" 1)
check "la tx de alice llega a bob" lab_wait_tx bob "$TX"
check "la tx de alice llega a carol (pasando por bob)" lab_wait_tx carol "$TX"
check "getmempoolinfo de carol: size=1" bash -c 'source lab.sh; carol getmempoolinfo | jq -e ".size == 1" >/dev/null'
alice -generate 1 >/dev/null
lab_wait_sync
check "tras minar, el mempool de carol queda vacío" bash -c 'source lab.sh; carol getmempoolinfo | jq -e ".size == 0" >/dev/null'
check "getchaintips: una sola punta, active" bash -c 'source lab.sh; alice getchaintips | jq -e "length == 1 and .[0].status == \"active\"" >/dev/null'

echo "== Track 2: los logs"
check "logging activa net y mempool sin reiniciar" bash -c '
  source lab.sh; alice logging "[\"net\",\"mempool\"]" | jq -e ".net and .mempool" >/dev/null'
bob logging '["net","mempool"]' >/dev/null
TX=$(alice sendtoaddress "$(bob getnewaddress)" 1)
lab_wait_tx bob "$TX" >/dev/null
sleep 1
ALICE_LOG=$(docker compose logs --no-log-prefix alice)
BOB_LOG=$(docker compose logs --no-log-prefix bob)
check "alice: sending inv → received: getdata → sending tx" bash -c '
  grep -qE "\[net\] sending inv \(" <<<"$1" && grep -qE "\[net\] received: getdata \(" <<<"$1" && grep -qE "\[net\] sending tx \(" <<<"$1"' _ "$ALICE_LOG"
check "bob: AcceptToMemoryPool ... accepted <txid>" grep -qE "AcceptToMemoryPool: peer=[0-9]+: accepted $TX" <<<"$BOB_LOG"
check "UpdateTip: new best= aparece en el log" grep -qE "UpdateTip: new best=" <<<"$BOB_LOG"

echo "== Track 3: la película (ZMQ)"
check "getzmqnotifications lista pubsequence" bash -c '
  source lab.sh; alice getzmqnotifications | jq -e "any(.[]; .type == \"pubsequence\" and .address == \"tcp://0.0.0.0:28332\")" >/dev/null'
docker compose exec -T alice sh -c 'python3 -u /lab/scripts/zmq_listen.py > /tmp/zmq.log 2>&1 & echo $! > /tmp/zmq.pid'
sleep 1
T1=$(alice -named sendtoaddress address="$(carol getnewaddress)" amount=1 replaceable=true)
lab_wait_tx carol "$T1" >/dev/null
T2=$(alice bumpfee "$T1" | jq -r .txid)
lab_wait_tx carol "$T2" >/dev/null
B=$(alice -generate 1 | jq -r '.blocks[0]')
lab_wait_sync
sleep 1
ZMQ=$(docker compose exec -T alice cat /tmp/zmq.log)
check "A <T1> (tx agregada)" grep -qE " A  $T1 " <<<"$ZMQ"
check "R <T1> (reemplazada por RBF)" grep -qE " R  $T1 " <<<"$ZMQ"
check "A <T2> (la que la reemplaza)" grep -qE " A  $T2 " <<<"$ZMQ"
check "C <bloque> (conectado)" grep -qE " C  $B " <<<"$ZMQ"
check "T2 entró al bloque sin generar R" bash -c '! grep -qE " R  $1 " <<<"$2"' _ "$T2" "$ZMQ"

echo "== Track 4: la conversación P2P y el fork"
check "bob → carol: bytessent_per_msg incluye version, verack, inv, tx" bash -c '
  source lab.sh; bob getpeerinfo | jq -e "map(select(.addr|startswith(\"carol\")))[0].bytessent_per_msg | has(\"version\") and has(\"verack\") and has(\"inv\") and has(\"tx\")" >/dev/null'
check "addconnection crea una conexión block-relay-only alice → carol" bash -c '
  source lab.sh; alice addconnection carol:18444 block-relay-only false | jq -e ".connection_type == \"block-relay-only\"" >/dev/null'
sleep 2
BRO_ID=$(alice getpeerinfo | jq '.[] | select(.connection_type == "block-relay-only") | .id')
TX=$(alice sendtoaddress "$(carol getnewaddress)" 1)
lab_wait_tx carol "$TX" >/dev/null
sleep 1
check "alice nunca manda la tx al peer block-relay-only (peer=$BRO_ID)" bash -c '
  ! docker compose logs --no-log-prefix alice | grep -qE "sending (inv|tx) \([0-9]+ bytes\) peer=$1\$"' _ "$BRO_ID"
alice -generate 1 >/dev/null
lab_wait_sync

# Fork: alice incluye una tx en un bloque mientras está aislada; carol mina 2.
lab_split >/dev/null
check "red partida: 0 conexiones" test "$(alice getconnectioncount)$(bob getconnectioncount)$(carol getconnectioncount)" = "000"
TX=$(alice sendtoaddress "$(alice getnewaddress)" 1)
FORK_BLOCK=$(alice -generate 1 | jq -r '.blocks[0]')
carol -generate 2 >/dev/null
check "alice y carol tienen tips distintos" test "$(alice getbestblockhash)" != "$(carol getbestblockhash)"
lab_join >/dev/null
lab_wait_sync
check "getchaintips de alice: active + valid-fork (branchlen 1)" bash -c '
  source lab.sh; alice getchaintips | jq -e "map(.status) | sort == [\"active\",\"valid-fork\"]" >/dev/null && alice getchaintips | jq -e "map(select(.status==\"valid-fork\"))[0].branchlen == 1" >/dev/null'
check "el bloque de alice quedó fuera de la cadena (confirmations = -1)" bash -c '
  source lab.sh; alice getblock "$1" | jq -e ".confirmations == -1" >/dev/null' _ "$FORK_BLOCK"
check "la tx de alice volvió a su mempool" bash -c 'source lab.sh; alice getrawmempool | grep -q "$1"' _ "$TX"
sleep 1
ZMQ=$(docker compose exec -T alice cat /tmp/zmq.log)
check "ZMQ de alice: C <bloque de alice> y después D <bloque de alice>" bash -c '
  grep -qE " C  $1 " <<<"$2" && grep -qE " D  $1 " <<<"$2"' _ "$FORK_BLOCK" "$ZMQ"
check "ZMQ de alice: la tx se agrega dos veces (A antes del bloque, A tras el reorg)" bash -c '
  test "$(grep -cE " A  $1 " <<<"$2")" = 2' _ "$TX" "$ZMQ"
FORK_HEIGHT=$(alice getblock "$FORK_BLOCK" | jq .height)
check "debug.log de alice: tras UpdateTip a su bloque (altura $FORK_HEIGHT) vuelve a la altura $((FORK_HEIGHT - 1))" bash -c '
  docker compose logs --no-log-prefix alice | grep -oE "UpdateTip: new best=[0-9a-f]+ height=[0-9]+" \
    | grep -A1 "$1" | tail -1 | grep -q "height=$2\$"' _ "$FORK_BLOCK" "$((FORK_HEIGHT - 1))"

docker compose exec -T alice sh -c 'kill "$(cat /tmp/zmq.pid)"' || true
echo
echo "Todo OK."
