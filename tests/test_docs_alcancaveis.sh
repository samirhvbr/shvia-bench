#!/usr/bin/env bash
# Todo `.md` de `docs/` é alcançável por LINK a partir de um índice — achado D-DOC-10.
#
# O critério, por extenso: para cada `docs/*.md`, existe em algum índice
# (`README.md`, `README_br.md`, `CLAUDE.md`, `AGENTS.md`) ou em outro documento um
# link markdown que aponte para ele.
#
# Por que link e não menção: `docs/rodar.md` já aparecia no README — dentro da
# ÁRVORE DE ARQUIVOS, num bloco de código, onde link não renderiza. Um humano lendo
# de cima a baixo encontra; quem procura clicando, não. A revisão registrou isso como
# "órfão", o que era forte demais, e como "o README aponta só ambiente-isolado.md",
# o que era exato: só aquele era LINK. Agora os dois são.
#
# Doc órfã não é doc velha: é doc que ninguém sabe que existe, e o custo dela não é o
# arquivo — é alguém refazer o que já estava pronto.
set -u
cd "$(dirname "$0")/.."

indices=""
for f in README.md README_br.md CLAUDE.md AGENTS.md docs/README.md; do
  [ -f "$f" ] && indices="$indices$(cat "$f")"
done
# Documentos linkam entre si: alcançado por outro doc também conta.
for f in docs/*.md; do
  [ -f "$f" ] && indices="$indices$(cat "$f")"
done

orfaos=""
for f in docs/*.md; do
  [ -f "$f" ] || continue
  [ "$f" = "docs/README.md" ] && continue   # o índice não precisa ser linkado
  nome="$(basename "$f")"
  case "$indices" in
    *"]($f)"*|*"]($nome)"*|*"/$nome)"*) : ;;
    *) orfaos="$orfaos $f" ;;
  esac
done

if [ -n "$orfaos" ]; then
  echo "❌ documento(s) em docs/ sem NENHUM link apontando para eles:"
  for o in $orfaos; do echo "   $o"; done
  echo "   Linke no README (link markdown de verdade, não menção na árvore) ou apague."
  exit 1
fi

n=$(ls docs/*.md 2>/dev/null | wc -l)
[ "$n" -gt 0 ] || { echo "❌ docs/ vazio — a régua estaria medindo o vazio"; exit 1; }
echo "OK: $n documento(s) em docs/, todos alcançáveis por link."
