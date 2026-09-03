# SHVIA-BENCH — Instruções para agentes de código

> **Leia também:** [README.md](README.md) / [README_br.md](README_br.md) ·
> [docs/ambiente-isolado.md](docs/ambiente-isolado.md) (a spec, v0.2) ·
> [.continue/estado-atual.md](.continue/estado-atual.md) (log de progresso).
>
> `CLAUDE.md` e `AGENTS.md` são **espelhados** abaixo do H1 — editar os dois.

---

## 🔄 Antes de começar: `git pull`

**SEMPRE** verifique atualizações remotas antes de escrever ou alterar qualquer
coisa neste repositório.

---

## O que é este repo

**Ambiente isolado + instrumentação** para benchmark de LLMs em tarefas de
engenharia de software. NÃO é rubrica nem suíte de tarefas — é a camada de baixo:
sandbox estéril (`env -i` + HOME sandbox + `CLAUDE_CONFIG_DIR`) + proxy de
verdade-base + catálogo de métricas + auditoria de isenção. Consome o **LEB**
(repo público [AI-BENCHMARK](https://github.com/samirhvbr/AI-BENCHMARK)) como fonte de tarefas nº 1.

Stack: **bash + python (só stdlib)**. Sem deps externas — portável e auditável.

---

## Padrão de Commits (obrigatório)

Formato: `versão - comentário em português`. A versão **sempre** vem de
`version.md` (bumpe no mesmo commit). Critério: **Z** = ajuste de runner/UX/doc;
**Y** = nova métrica, mudança no protocolo de coleta ou no schema; **X** =
estável/campanha publicada. Proibido `feat:`/`fix:`/`chore:` e mensagens vagas.

---

## Invariantes do produto (não relitigar sem registrar na spec)

- **A fronteira de isolamento é `HOME` + ambiente do processo**, não a pasta de
  trabalho (§4.0). Todo run passa por `env -i` + HOME sandbox recriado do
  template + `CLAUDE_CONFIG_DIR` isolado. **Nunca** tocar no `~/.claude` real.
- **`runs/` é WRITE-ONLY.** Nenhum processo de execução lê de `runs/` — isso
  impede resultado anterior realimentar execução futura (§4.1). O que o invariante
  protege é a **execução do modelo**: por isso a retomada de campanha é do
  OPERADOR (`--from-rep N`), não do driver — derivar controle de fluxo do próprio
  ledger seria exatamente a realimentação proibida. Passos de **pós-run**
  (`patch-results`, `reclassify`, sumário) leem `runs/` legitimamente: rodam depois
  da execução e não alimentam modelo nenhum.
- **Dado pago não se destrói.** Cada linha de `results.jsonl` custou dinheiro real
  (ordem de US$1/rep no Opus). Nada no repo pode truncar ou sobrescrever resultado
  existente: o driver **recusa** e ensina a retomar; escrita de resultado é sempre
  atômica (`os.replace`); falha transitória do verificador mantém a rep
  **pendente e reverificável**, nunca a consome.
- **`failed_verification` é do VERIFICADOR, nunca do harness** (§10.4). `status` é
  função pura de dois eixos ortogonais — `harness_outcome` (a execução produziu
  medição válida?) × `verification` (a entrega passou?) —, arbitrada num único
  ponto (`runner/status.py`). Erro de API/infra é `infra_error`: nunca vira nota do
  modelo. Desfecho desconhecido cai em `infra_error` **com a anomalia crua anexada**,
  jamais num fallback silencioso.
- **Segredos nunca versionados.** A chave vive em `.secrets/` (gitignored),
  injetada individualmente pelo `run.sh`. Nunca `source .env`, nunca em argv.
- **Nada de interno da Blue3 aqui.** Sem o gateway interno, sem o CLI interno,
  sem hostnames/URLs privados, sem chaves. Repo público e reprodutível por terceiros.
- **Proxy passivo:** não modifica o **corpo**; preserva os headers, **exceto o
  `Host`** (reescrita de transporte, obrigatória para nomear o upstream). Se
  modificasse o corpo, viraria variável do experimento (§4.4).
- **Auditoria é bloqueante:** se o bloco A falhar, o run aborta (`audit_passed:false`).
- **Métrica ausente = `null`, nunca `0`** (§10.3). Um harness sem contagem de
  subagente não tem "0 subagentes".
- **Custo/tokens: C3 → C2-dedup → C1, e a fonte vai gravada** (§10.1). O C3 fica no
  topo por princípio (única camada externa ao harness), mas só é eleito com
  **cobertura total** da janela — presença parcial publicaria ordens de grandeza a
  menos com o selo da camada mais confiável. O C2 é agregado por `message.id`
  (**máximo por bucket**, nunca soma: o streaming repete a mesma mensagem). Todo
  registro carrega `cost.usage_source` — sem ela o `cost_delta_pct` não é
  interpretável —, e **nenhuma fonte ⇒ `null`, nunca `0`**: custo zero num run pago
  é pior que custo ausente. O `usage` top-level do C1 **não** é confiável como
  agregado do run: mediu-se omitindo uma chamada inteira.
- **Esforço/raciocínio sempre explícitos** e idênticos por campanha (V17); nunca
  herdados, nunca omitidos.
- **Flags/campos do Claude Code são hipóteses a validar** a cada versão (§6.2, §15).
  O canário A5 (§11) e o proxy C3 (§4.4) são as duas verificações que não envelhecem.

---

## Stack & comandos

- `./preflight.sh` — checa python3/openssl/git/docker e o estado do repo.
- `runner/run.sh <cmd...>` — roda `<cmd>` no ambiente sanitizado.
- `runner/audit.sh` — bloco A mecânico (retorna ≠0 se algum check bloqueante falha).
- `runner/canary.sh --selftest` — prova o detector A5 offline (fixtures).
- `bash tests/run_all.sh` — **a suíte offline inteira** (sem rede/chave/docker).
  Rode isto, não os arquivos soltos: foi assim que um teste ficou vermelho sem
  ninguém notar.
- `python3 proxy/logging_proxy.py` — sobe o proxy passivo.

---

## Referências rápidas

- Versão: `version.md` · Spec: [docs/ambiente-isolado.md](docs/ambiente-isolado.md)
- Fonte de tarefas (LEB): `github.com/samirhvbr/AI-BENCHMARK` (clonar ao lado; override via `LEB_ROOT`)
- Log de progresso: [.continue/estado-atual.md](.continue/estado-atual.md)

---

## PS — Commits: a skill COMMITTER cuida disso

**Existe `.committer.yml` na raiz deste repositório** — é o opt-in da skill
**COMMITTER**, que roda em ciclo (cron, via `~/x/GIT/run.sh`). Enquanto esse arquivo
existir com `enabled: true`, **commitar e pushar não é trabalho seu**.

**O que muda para você:**

- **Não commite nem pushe por padrão.** Conclua a entrega bumpando o `version.md`
  **com a entrada de changelog** e deixe a árvore pronta. É dali que a mensagem do
  commit sai — o changelog virou o artefato de handoff entre você e a skill.
- A skill monta `X.Y.Z - descrição`, commita e pusha a branch atual sozinha. Ela
  **nunca bumpa versão** (isso continua sendo julgamento seu) e nunca inventa
  mensagem: sem entrada de changelog ela cai num fallback Sonnet, e sem conseguir
  descrever com honestidade ela aborta e espera.

**Você ainda commita quando:**

- o Samir pedir explicitamente;
- a tarefa exigir o SHA na hora (deploy, abrir PR, referência cruzada);
- o `.committer.yml` sumir ou estiver `enabled: false` — aí vale o fluxo antigo,
  você bumpa, commita e pusha.

**Por que isso existe:** tirar de um modelo caro (Opus/Fable) o trabalho mecânico de
empacotar commit, que um Sonnet — ou, na maioria das vezes, nenhum modelo — resolve.
Economiza token e devolve tempo de desenvolvimento.

---

<!-- RELEASES-RULE:repodocs -->

## Releases — the `version.md` on GitHub is what the Releases show

> Marked echo. The single source is **[samirhvbr/repodocs](https://github.com/samirhvbr/repodocs/blob/master/docs/versioning.md)**
> — change it there, not here. This block is regenerated.

**The `version.md` of the default branch, on GitHub, is what the GitHub Releases
must show.** The local checkout does not enter the calculation: it can be behind,
ahead or mid-work, and none of that is published — GitHub cannot tag a commit it
does not have.

**The bump and the Release are one act.** A commit that bumps `version.md` is not
finished until that version has a tag, a published Release, and the **`Latest`
badge on it** — the same push, not "later". A badge sitting on an older release
tells whoever looks that the project is at a version it is not.

- `.github/workflows/release.yml` does it on any push that touches `version.md`.
- `./tools/release.sh` does it by hand. It is **idempotent and self-healing**:
  it publishes whatever is missing and moves a drifted badge back. Running it is
  always safe, so it is both the check and the fix.

A PR publishes nothing while it is a PR. The moment it merges, the push moves
`version.md` on the default branch and the Release becomes that version.

Tag and Release title are the **bare version — no `v` prefix**.

<!-- /RELEASES-RULE -->
