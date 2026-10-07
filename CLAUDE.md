# SHVIA-BENCH — Instruções para Claude Code

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

Formato: `X.Y.Z - description in English (US)`. A versão **sempre** vem de
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

<!-- COMMIT-RULE:repodocs -->

## Commits — you commit, and nothing is delivered until you have

> Marked echo. The single source is **[samirhvbr/repodocs](https://github.com/samirhvbr/repodocs/blob/master/docs/versioning.md#who-commits-and-when)**
> — change it there, not here. This block is regenerated.

**Committing is your job.** Not "leave the tree ready and something downstream
packages it" — you run `git commit`, and `git push`, as the last step of the work
you were asked to do. The COMMITTER skill that used to commit on an agent's
behalf is `enabled: false` in every repository of this fleet since 03/09/2026;
what is left of it is a kill-switch, not a scheduler. **If you do not commit,
nobody does.**

**Do not report a task as finished before the commit exists.** "Done",
"delivered", "concluded" mean the work is in `git log` — never that it is sitting
uncommitted where only this session can see it. The commit is the last step *of
the task*, not a follow-up for someone else. If you are about to write
"finished", commit first, then write it.

**Push is part of the delivery, and a refused push is the one place a human enters.**
Commit *and* push, every delivery — a clean push needs nobody's permission and is never
held back for review. When the push is **refused** (conflict, non-fast-forward, protected
branch), stop there and say so: never force, never rewrite history to get past it, never
invent a merge resolution you have not verified. The gate is the refused push, not the
commit.

**Every commit obeys the versioning rules**, with no exception:

- Subject `X.Y.Z - short description in English (US)`, the version taken from
  `version.md` and **bumped in the same commit**.
- The `CHANGELOG.md` entry is written first — its `## X.Y.Z - description`
  heading *is* the subject.
- No Conventional Commits prefix (`feat:`, `fix:`, `chore:`) and no vague
  subject ("update", "ajuste", "wip", "changes", "several improvements").

**The bump is the one clause a repository may override — in writing.** If this
repository's own documentation says the version is stamped some other way, and says
why, follow that. Otherwise the line above applies to you. An override nobody wrote
down is not an exception. Nothing else in this block bends: the changelog entry, the
subject, the language, one subject per commit, and committing before you report done
all hold regardless.

**An override moves *when* the version is decided, never *whether* every commit
carries it.** A delivery split into blocks — the default — must come out with the
version on **every** subject, not on the last one. A placeholder left in a subject
that reaches the default branch is a defect and is permanent, because the default
branch is not rewritten. Measured: 26 of them in the one repository that stamps at
merge, before its mechanism was fixed.

**All of this governs the repositories we own.** In a repository that is not
ours, the host's commit convention governs instead — their subject line, in
their language. `X.Y.Z` is meaningless where there is no `version.md` of ours,
and there is no version there for us to bump. Our versioning rules govern our
remotes, not every remote we can push to.

**One subject per commit.** The subject has to describe the whole commit
honestly. The moment your description needs an "and" to be true, it is two
commits.

**Split a large delivery into blocks.** A complex task is committed as a series
of commits grouped by subject, each small enough to be described in one line and
read on its own. They may share a version — bump `version.md` in the first and
repeat the number in the rest; two commits carrying one version is expected, not
a mistake. **Splitting is the default** for anything non-trivial, because the
history is the documentation of *how* the work was done, and one commit touching
six unrelated subjects documents none of them.

**The standard you are keeping:** someone reading `git log` alone — a year from
now, without the conversation that produced the work — can say what happened,
when, why, and at which version. If your commit would fail that test, it is too
big or its subject is too vague, and both are fixed the same way.

<!-- /COMMIT-RULE -->

---

<!-- LANGUAGE-RULE:repodocs -->

## Language — English (US) at home, the upstream's when we are guests

> Marked echo. The single source is **[samirhvbr/repodocs](https://github.com/samirhvbr/repodocs/blob/master/docs/conventions.md#8-language)**
> — change it there, not here. This block is regenerated.

**Everything that lives in this repository, or in GitHub's interface around it,
is written in English (US)**: documents, **commit messages**, pull request titles
and bodies, issues, code comments, changelog entries, release notes.

Commit format: `X.Y.Z - short description in English`. The version comes from
`version.md` and is bumped in the same commit. Conventional Commits prefixes
(`feat:`, `fix:`, `chore:`) and vague one-word messages are forbidden.

**Three carve-outs, and only three.** The first is end-user-facing strings — UI
text, transactional email, product copy: product i18n for a Brazilian audience,
not repository content. The second is the **Blue3 internal repositories**
(`BLUE3-ISP/*`, `samirhvbr/blue3-intranet`, `samirhvbr/blue3-ai-login`), which
are Portuguese throughout — if you are reading this block inside one of them,
this is the wrong block: they carry `LANGUAGE-RULE-PT`. A repository joins that
set by a written decision, never by argument.

**The third is `.continue/`.** The queue is written in the language its author
thinks in, and becomes English (US) when the work is **produced** and the
document moves to `docs/`. A Portuguese draft in the queue is not a violation to
be fixed: it is unfinished work in the language it is being thought in, and
translating it or moving it out before the thing exists destroys the only place
that thing exists.

History is not rewritten: Portuguese messages already in the log stay as they
are.

**In a repository that is not ours, the upstream's conventions win — the
language and the commit shape both.** Opening a pull request or an issue on a
repository we do not own makes us guests, and a guest writes in the host's
language. Our `X.Y.Z - description` is meaningless there anyway: they have no
`version.md` of ours, and no version for us to bump.

**Check before you write, and the first signal that answers wins:** a written
instruction (`CONTRIBUTING.md`, a pull request or issue template, a contribution
section in the README), then the last ~20 merged pull requests, then the issues,
then the commit log. A written instruction beats observed practice — if they ask
for English and their log is Portuguese, write English. Below that line the
**clear majority** decides, and clear means clear.

**When you cannot tell, write English (US).** A private repository, an empty
history, no network, a refused `gh` call and a genuinely mixed log all land in
the same place — the house rule. Unverifiable is not a licence to guess.

**This is a scope boundary, not a second carve-out.** Nothing in *our*
repositories changes because a foreign one is Portuguese, and code identifiers
are English wherever you are.

<!-- /LANGUAGE-RULE -->

<!-- CICD-RULE:repodocs -->

## CI — the fleet's self-hosted runner is open to every repository

> Marked echo. The single source is **[samirhvbr/repodocs](https://github.com/samirhvbr/repodocs/blob/master/docs/ci.md)**
> — change it there, not here. This block is regenerated.

**The fleet has one CI machine, `cicd`: a self-hosted GitHub Actions runner that
does not spend the account's hosted minutes.** It exists because that budget ran
out on 25/09/2026 and every job in a private repository failed within seconds,
with zero steps.

| | |
|---|---|
| Address | `100.64.100.240` — the office network only. RFC 6598 shared space: not routable from the internet |
| Access | `ssh samir@100.64.100.240` |
| Dashboard | `http://100.64.100.240:8080/` — read-only, no login, office network only. It shows the jobs; it is **not** how a repository joins |

**Every repository may use it, public ones included** — the owner's decision of
07/10/2026. Until that date a public repository was forbidden, and the reason has
not gone away: **a pull request from any fork runs its author's code on this
machine**, where the jobs have passwordless `sudo` and `docker`, which is
effectively root on a machine inside the office network. What stands where the
prohibition stood is one setting, per repository: *Settings → Actions → Fork pull
request workflows → **Require approval for all external contributors***. On a
public repository on `cicd`, that setting is not optional.

**Permission is not destination.** A job reads
`runs-on: ${{ vars.CI_RUNNER || 'ubuntu-latest' }}`, so nothing moves until
somebody sets the variable:
`gh variable set CI_RUNNER --body shvia-ci -R <owner>/<repo>` sends the jobs to
`cicd`, `gh variable delete CI_RUNNER -R <owner>/<repo>` hands them back to
GitHub. **Never set it at organisation scope** — that retargets every repository
at once, public ones that run free on hosted minutes included.

**Joining is pre-authorised; registering is still the owner's act.** One runner
per repository, registered over SSH with a one-hour token. The jobs run with
`sudo` on a machine inside the office network, so an agent **never registers a
runner on its own initiative**: it says what is needed and asks. A repository
belonging to somebody else's account is not covered by the decision above — that
one is still decided case by case.

<!-- /CICD-RULE -->

<!-- QUEUE-RULE:repodocs -->

## The queue empties by production, and by nothing else

> Marked echo. The single source is **[samirhvbr/repodocs](https://github.com/samirhvbr/repodocs/blob/master/docs/conventions.md#1-continue-is-the-queue--docs-is-what-has-been-produced)**
> — change it there, not here. This block is regenerated.

**`.continue/` holds work that does not exist yet.** A document leaves it when —
and **only** when — the thing it describes **exists**. Length is not an exit
condition. Neither is age, language, untidiness, the end of a session, or an
agent who would have written it differently.

> `tela.md` says *"a black screen with a yellow ball in the middle"*. It leaves
> the queue when there is a black screen with a yellow ball. Until then it stays,
> at any length, in whatever shape it is in — because until then it is the only
> place that thing exists.

**"Produce", applied to a queue item, means making the thing exist.** Not editing
the document, not translating it, not promoting it to `docs/`. The document is
the specification; the deliverable is the thing. Removing the document is the
**last step of the commit that carries the work** — never a step of its own.

**Never empty this folder as tidying.** A queue item deleted without the work
being done destroys the only artefact a project has before it has code — and
what usually replaces it is worse than the loss: a `docs/` page describing a
screen nobody built, indistinguishable from a page describing one that exists.
If a plan has to be visible in `docs/` before it is built, it is `PROPOSED`,
never `ACTIVE`.

**The half-a-page rule is about a record that ended up in the queue**, and about
nothing else. It has no opinion on the length of a specification of unbuilt
work: a 1,300-line brief about something that does not exist is in the only
place it can be. A long queue item is a project with a lot still to build.

**The queue is written in the language its author thinks in**, and becomes
English (US) on the way out, when the work is produced and the document moves to
`docs/`. A Portuguese draft in `.continue/` is not a violation to be fixed.

<!-- /QUEUE-RULE -->

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
