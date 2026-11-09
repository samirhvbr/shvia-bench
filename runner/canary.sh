#!/usr/bin/env bash
# runner/canary.sh — canário de ferramentas (auditoria A5, spec §11).
#
# Premissa: um MCP herdado (não previsto) dá ao modelo ferramentas que outra
# execução não tem — contaminação. O canário PLANTA um MCP único e prova que,
# sob nosso isolamento (--mcp-config vazio + --strict-mcp-config), ele NÃO
# aparece. As flags de MCP têm bugs conhecidos (§6.2); por isso a verificação é
# EMPÍRICA, não confiança na flag.
#
# Modos:
#   canary.sh --selftest        OFFLINE: prova o servidor canário (expõe o tool)
#                               e o DETECTOR (fixtures) — sem modelo, sem chave.
#   canary.sh --live [--out F]  AO VIVO: roda o `claude` isolado e verifica que o
#                               tool canário não vazou. Precisa de chave+claude.
#                               Exit 0 = isolated, 1 = leaked, 3 = inconclusive (the
#                               session never listed its tools), 2 = cannot run.
#   canary.sh --detect FILE     só roda o detector sobre um arquivo (sai 0=vazou).
set -uo pipefail

BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANARY_TOOL="shvia_bench_canary"          # token único do tool plantado
CANARY_SERVER="config/canary_mcp_server.py"

# detector compartilhado: sai 0 se o token do canário aparece (VAZOU), 1 se limpo
detect_canary() { grep -q "$CANARY_TOOL" "$1"; }

# Did the claude session start and list its tools? The stream-json `init` event carries the
# list. Without it, "the canary is absent" proves nothing: until 0.9.6 a claude that failed
# (no key, no quota, a crash) left an empty file, and the canary read it as clean.
session_listed_tools() {
  python3 -c '
import json, sys
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try:
        e = json.loads(line)
    except ValueError:
        continue
    if isinstance(e, dict) and e.get("type") == "system" and e.get("subtype") == "init" \
            and isinstance(e.get("tools"), list) and e["tools"]:
        sys.exit(0)
sys.exit(1)' "$1"
}

# The verdict of one live run's output: leaked | clean | inconclusive.
canary_verdict() {
  if detect_canary "$1"; then echo leaked
  elif session_listed_tools "$1"; then echo clean
  else echo inconclusive
  fi
}

selftest() {
  local ok=1
  echo "== canary --selftest (offline) ==" >&2

  # (1) o servidor canário realmente EXPÕE o tool no tools/list?
  local out
  out="$(printf '%s\n' \
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"selftest","version":"0"}}}' \
      '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
      '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
    | python3 "$BENCH_ROOT/$CANARY_SERVER" 2>/dev/null)"
  if printf '%s' "$out" | grep -q "$CANARY_TOOL"; then
    echo "  [pass] servidor canário expõe '$CANARY_TOOL' no tools/list" >&2
  else
    echo "  [FAIL] servidor canário NÃO expôs o tool — canário seria cego" >&2; ok=0
  fi

  # (2) o DETECTOR pega o vazamento e passa no limpo?
  if detect_canary "$BENCH_ROOT/tests/fixtures/tools_with_canary.txt"; then
    echo "  [pass] detector ACHA o canário na fixture 'with_canary' (=vazou)" >&2
  else
    echo "  [FAIL] detector não achou o canário quando deveria" >&2; ok=0
  fi
  if detect_canary "$BENCH_ROOT/tests/fixtures/tools_clean.txt"; then
    echo "  [FAIL] detector achou canário na fixture 'clean' (falso positivo)" >&2; ok=0
  else
    echo "  [pass] detector NÃO acusa a fixture limpa (=sem vazamento)" >&2
  fi

  # (3) the verdict needs the session's own tool list before it can say "clean"
  local v
  for pair in "stream_init_with_canary.jsonl:leaked" "stream_init_clean.jsonl:clean" "stream_no_init.jsonl:inconclusive"; do
    v="$(canary_verdict "$BENCH_ROOT/tests/fixtures/${pair%%:*}")"
    if [ "$v" = "${pair##*:}" ]; then echo "  [pass] veredito de '${pair%%:*}' = $v" >&2
    else echo "  [FAIL] veredito de '${pair%%:*}' = $v, esperado ${pair##*:}" >&2; ok=0; fi
  done

  if [ "$ok" -eq 1 ]; then echo "== selftest OK: mecanismo do canário A5 provado offline ==" >&2; return 0
  else echo "== selftest FALHOU ==" >&2; return 1; fi
}

live() {
  local out_json="${1:-}"
  if ! command -v claude >/dev/null 2>&1; then echo "canary --live: 'claude' ausente." >&2; return 2; fi
  if [ ! -f "$BENCH_ROOT/.secrets/anthropic" ]; then
    echo "canary --live: falta .secrets/anthropic (chave do bench). Rode --selftest offline." >&2; return 2
  fi
  local tmp; tmp="$(mktemp)"
  # Planta o canário no HOME sandbox (config de usuário) e roda ISOLADO com
  # mcp vazio + strict. Se o isolamento vale, o tool não aparece no init.
  PLANT_CANARY=1 "$BENCH_ROOT/runner/run.sh" --task canary-a5 --no-audit -- \
    claude -p "List every tool name available to you, one per line." \
      --mcp-config "$BENCH_ROOT/config/mcp.empty.json" --strict-mcp-config \
      --output-format stream-json --verbose \
    > "$tmp" 2>/dev/null || true
  local verdict leaked ev="nenhuma" rc
  verdict="$(canary_verdict "$tmp")"
  case "$verdict" in
    leaked) leaked=true; ev="$(grep -m1 "$CANARY_TOOL" "$tmp" | cut -c1-160)"; rc=1 ;;
    clean)  leaked=false; rc=0 ;;
    *)      leaked=null; ev="a sessão do claude não listou ferramentas (falhou antes do init)"; rc=3 ;;
  esac
  local result="{\"leaked\":$leaked,\"verdict\":\"$verdict\",\"tool\":\"$CANARY_TOOL\",\"evidence\":\"$(printf '%s' "$ev" | sed 's/"/\\"/g')\"}"
  if [ -n "$out_json" ]; then printf '%s\n' "$result" > "$out_json"; echo "canary result → $out_json" >&2; fi
  printf '%s\n' "$result"
  rm -f "$tmp"
  return "$rc"   # 0 = isolation held, 1 = leaked, 3 = inconclusive (proves nothing)
}

case "${1:---selftest}" in
  --selftest) selftest ;;
  --detect)   detect_canary "${2:?--detect FILE}" && { echo "VAZOU"; exit 0; } || { echo "limpo"; exit 1; } ;;
  --live)     shift; out=""; [ "${1:-}" = "--out" ] && out="${2:?}"; live "$out" ;;
  -h|--help)  sed -n '2,20p' "${BASH_SOURCE[0]}" ;;
  *)          echo "modo desconhecido: $1 (use --selftest | --live | --detect)" >&2; exit 2 ;;
esac
