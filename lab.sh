# Atajos para el lab. Cargalos desde la raíz del repo:
#
#   source lab.sh
#
# Después `alice getpeerinfo` es lo mismo que
# `docker compose exec -T alice bitcoin-cli getpeerinfo`.

export COMPOSE_FILE="$PWD/docker-compose.yml"

alice() { docker compose exec -T alice bitcoin-cli "$@"; }
bob()   { docker compose exec -T bob   bitcoin-cli "$@"; }
carol() { docker compose exec -T carol bitcoin-cli "$@"; }

# Crea una wallet en cada nodo y mina 101 bloques para alice
# (las recompensas de coinbase recién se pueden gastar después de 100 bloques).
# Se puede correr más de una vez: reusa las wallets y solo mina si hace falta.
lab_setup() {
  local node
  for node in alice bob carol; do
    if ! "$node" listwallets | grep -q "\"$node\""; then
      "$node" loadwallet "$node" >/dev/null 2>&1 || "$node" createwallet "$node" >/dev/null
    fi
  done
  if [ "$(alice getblockcount)" -lt 101 ]; then
    alice generatetoaddress 101 "$(alice getnewaddress)" >/dev/null
  fi
  lab_wait_sync
  echo "Listo: alice tiene $(alice getbalance) BTC; los tres nodos están en el bloque $(carol getblockcount)."
}

# Espera hasta que los tres nodos tengan el mismo tip.
lab_wait_sync() {
  local i
  for i in $(seq 1 30); do
    if [ "$(alice getbestblockhash)" = "$(bob getbestblockhash)" ] &&
       [ "$(bob getbestblockhash)" = "$(carol getbestblockhash)" ]; then
      return 0
    fi
    sleep 1
  done
  echo "Los nodos no se sincronizaron en 30 s" >&2
  return 1
}

# Espera hasta que una tx aparezca en el mempool de un nodo: lab_wait_tx <nodo> <txid>
lab_wait_tx() {
  local i
  for i in $(seq 1 30); do
    if "$1" getrawmempool | grep -q "$2"; then
      echo "$1 vio la tx después de ~${i}s"
      return 0
    fi
    sleep 1
  done
  echo "$1 no vio la tx en 30 s" >&2
  return 1
}

# Parte la red: cada nodo apaga toda su actividad P2P.
lab_split() {
  local node
  for node in alice bob carol; do "$node" setnetworkactive false >/dev/null; done
  echo "Red partida: alice, bob y carol están aislados."
}

# Vuelve a conectar la red. Las conexiones de -addnode se restablecen solas,
# pero Bitcoin Core reintenta cada 60 s (src/net.cpp), así que forzamos un
# intento inmediato con `addnode ... onetry`.
lab_join() {
  local node
  for node in alice bob carol; do "$node" setnetworkactive true >/dev/null; done
  alice addnode bob:18444 onetry
  bob addnode carol:18444 onetry
  echo "Red reconectada."
}
