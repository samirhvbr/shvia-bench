#!/usr/bin/env bash
# run_all.sh — a suíte offline inteira, num comando.
#
# Existe porque "suíte verde" não pode depender de o operador lembrar de rodar
# seis arquivos na mão: na 0.6.2 um teste ficou VERMELHO sem ninguém notar,
# porque só os outros foram rodados.
#
# Tudo aqui é OFFLINE: sem rede, sem chave de API, sem docker. Sai != 0 se
# qualquer suíte falhar.
#
# Num repo de MEDIÇÃO, "verde" precisa significar "N checks rodaram", não
# "ninguém gritou". Por isso:
#   - suíte PULADA é reportada, não somada ao verde;
#   - a suíte de taxonomia tem PISO de checks (apagar checks vira falha);
#   - cada suíte roda sob watchdog (travar = vermelho, não pendurar o CI).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || { echo "run_all: não consegui entrar em $ROOT" >&2; exit 1; }

WATCHDOG_S="${WATCHDOG_S:-300}"
# piso da suíte de taxonomia: cobre o incidente de 19/07/2026. Se cair abaixo
# disto, alguém removeu cobertura — é falha, não "verde".
TAXONOMY_MIN_CHECKS=60

FAILED=0
SKIPPED=0

# Watchdog portátil: `timeout(1)` quando existe (GNU coreutils, Linux), `perl`+alarm
# como reserva (o macOS não traz `timeout`).
#
# O script nasceu escrito e validado SÓ no macOS, e era o `perl` que estava fixo. Ele
# funciona nos dois lados, então a troca não é conserto de defeito — é preferir a
# ferramenta certa onde ela existe e parar de exigir `perl` num contêiner de CI enxuto.
#
# ⚠️ Os dois sinalizam estouro com códigos DIFERENTES: `timeout` sai **124**, o
# `perl`+SIGALRM sai **142**. O relatório abaixo aceita os dois — testar só um faria o
# "TRAVOU" desaparecer justamente na plataforma que não foi usada para escrever isto.
if command -v timeout >/dev/null 2>&1; then
  watchdog() { timeout "$WATCHDOG_S" "$@"; }
  WATCHDOG_RC_ESTOURO=124
elif command -v perl >/dev/null 2>&1; then
  watchdog() { perl -e 'alarm shift; exec @ARGV' "$WATCHDOG_S" "$@"; }
  WATCHDOG_RC_ESTOURO=142
else
  echo "run_all: sem \`timeout\` nem \`perl\` — não há watchdog, e suíte que pendura" >&2
  echo "         é pior que suíte vermelha. Instale coreutils ou perl." >&2
  exit 1
fi

run() {
  local out rc
  # 🔴 `-t` EXIGE `XXXXXX` no GNU mktemp; sem eles ele recusa (achado G-40).
  #
  # O template era `sb-test`, sem X nenhum. No macOS passa; no Linux o mktemp sai com
  # erro, `$out` fica VAZIO, e daí em diante todo `> "$out"` e `cat "$out"` falha — as
  # 8 suítes eram reportadas como FALHOU sem nunca terem rodado. Medido em 02/09 antes
  # do conserto: `8 suíte(s) FALHARAM` e `COBERTURA ABAIXO DO PISO: ? < 60`, com as
  # suítes passando quando chamadas à mão.
  #
  # E o `|| morrer` é a metade que faltava: num repo de MEDIÇÃO, uma falha de
  # infraestrutura do próprio runner não pode se disfarçar de suíte vermelha. Ou o
  # arquivo temporário existe, ou o script para dizendo por quê.
  out="$(mktemp -t sb-test.XXXXXX)" || {
    echo "run_all: mktemp falhou — não consigo capturar a saída das suítes." >&2
    echo "         Sem isso, TUDO seria reportado como falha sem ter rodado." >&2
    exit 1
  }
  echo "── $* ─────────────────────────────────────────"
  if watchdog "$@" > "$out" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  if [ "$rc" -eq 0 ]; then
    tail -1 "$out"
    if grep -q "SKIP" "$out"; then
      echo "   ^^ PULADA (dependência ausente) — não conta como verde"
      SKIPPED=$((SKIPPED + 1))
    fi
  else
    cat "$out"
    [ "$rc" -eq "$WATCHDOG_RC_ESTOURO" ] && echo "   ^^ TRAVOU (watchdog ${WATCHDOG_S}s)"
    echo "   ^^ FALHOU: $*"
    FAILED=$((FAILED + 1))
  fi
  # piso de cobertura da taxonomia
  case "$*" in
    *test_status_taxonomy_offline.py*)
      n="$(sed -n 's/.*(\([0-9]\{1,\}\) checks).*/\1/p' "$out" | tail -1)"
      if [ -z "${n:-}" ] || [ "$n" -lt "$TAXONOMY_MIN_CHECKS" ]; then
        echo "   ^^ COBERTURA ABAIXO DO PISO: ${n:-?} < $TAXONOMY_MIN_CHECKS checks"
        FAILED=$((FAILED + 1))
      fi ;;
  esac
  rm -f "$out"
}

run python3 tests/test_proxy_offline.py            # C3 / proxy passivo
run python3 tests/test_track_a_offline.py          # Trilha A multi-vendor
run python3 tests/test_track_b_offline.py          # Trilha B (harness fake) + collect
run python3 tests/test_status_taxonomy_offline.py  # taxonomia + reparo + guards do driver
run python3 tests/test_cost_truth_offline.py       # precedência C3→C2-dedup→C1 (§10.1)
run python3 tests/test_leb_offline.py              # adapter LEB (SKIP sem LEB_ROOT)
run bash    runner/canary.sh --selftest            # A5 offline (fixtures)
run bash    tests/test_docs_alcancaveis.sh        # D-DOC-10: nenhum doc órfão

echo
if [ "$FAILED" -eq 0 ] && [ "$SKIPPED" -eq 0 ]; then
  echo "SUÍTE OFFLINE: TUDO VERDE"
elif [ "$FAILED" -eq 0 ]; then
  echo "SUÍTE OFFLINE: verde, mas $SKIPPED suíte(s) PULADA(s) — cobertura incompleta"
else
  echo "SUÍTE OFFLINE: $FAILED suíte(s) FALHARAM${SKIPPED:+ · $SKIPPED pulada(s)}"
fi
exit "$FAILED"
