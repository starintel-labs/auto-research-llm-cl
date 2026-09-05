Research the current state of **Star-Lang** and produce a concrete architecture/design report for taking it from its present prototype/transitional state to a coherent production language/runtime.

Star-Lang is a **Common Lisp-only** language/runtime. Do not propose rewriting the compiler/runtime in Rust, Python, Go, JS, or another implementation language.

Treat these as current architectural constraints:

* Common Lisp owns the `.star` parser, source locations/origin chains, semantic validation, normalized IR, canonical manifests, lifecycle semantics, delivery semantics, deterministic dispatch, recovery, document construction, direct execution, optional `cl-gserver` integration, and public API.
* There must be **one semantic authority**. Avoid duplicated actor/runtime/compiler semantics across packages.
* The existing transitional `starlang-prototype` should eventually be decomposed into dependency-ordered ASDF systems rather than becoming a permanent monolith.
* Star-Lang actor systems should support bounded mailboxes, supervision/restart, durable jobs, journaling/replay, immutable revisions, leases/fencing, capabilities, artifact custody/commits, cancellation, readiness, durable evidence/outbox delivery, and process isolation where appropriate.
* Logic/expert-system integration is adapter-based. Supported backend identities include `swi-prolog`, `lisa`, and `n-prolog`.
* `:backend auto` must resolve deterministically during plan materialization and become immutable afterward.
* Typed facts, rules, goals, questions, conclusions, proofs, and uncertainty should lower into checked engine-neutral IR rather than passing raw Prolog source around.
* Star addressing follows hierarchical RFC 3986-style URIs:
  `star://<authority>/<resource-kind>/<resource-path>`
  Do not revive the rejected `domain:address:actor-name` model.
* Star-Lang must compose cleanly with `starintel-server`, whose runtime currently includes Common Lisp, Sento actors, RabbitMQ, CouchDB, and the HTTP stack.
* Do not create a second actor runtime if Sento/cl-gserver or existing Star runtime primitives already provide the needed mechanism. Clearly distinguish language semantics from runtime adapters.

Investigate the repository and existing research/specs before recommending changes.

Focus especially on:

1. **Language boundary**

   * What belongs to Star-Lang semantics?
   * What belongs to the compiler?
   * What belongs to runtime adapters?
   * What remains ordinary Common Lisp?
   * Define the smallest defensible semantic core.

2. **Compiler pipeline**
   Map the intended pipeline from:
   `.star source`
   → parser/AST
   → semantic analysis
   → normalized IR
   → validated execution plan
   → canonical manifest
   → runtime materialization/execution.

   Identify anywhere the current implementation skips, conflates, or duplicates these stages.

3. **Actor semantics**
   Determine which actor properties must be language-level guarantees versus implementation/runtime behavior:

   * identity
   * addressing
   * mailbox semantics
   * delivery guarantees
   * ordering
   * supervision
   * restart
   * deadlines
   * cancellation
   * readiness
   * durable state
   * replay
   * leases/fencing
   * stale-writer rejection
   * capabilities
   * local vs remote actors.

4. **Determinism**
   Define exactly what must be deterministic:

   * parsing
   * semantic validation
   * backend selection
   * plan materialization
   * manifest generation
   * routing decisions
   * replay/recovery behavior where possible.

   Identify nondeterministic inputs and where they must be captured as explicit data.

5. **Expert-system integration**
   Design the clean boundary between Star-Lang and Prolog/LISA/N-Prolog.
   Determine what the engine-neutral logic IR must contain and how proofs/results should return to Star-Lang without leaking backend-specific syntax into the semantic core.

6. **Package architecture**
   Inspect the current ASDF/package layout and propose a dependency graph for extracting `starlang-prototype` into focused systems.
   Avoid speculative micro-packages. Prefer a small number of packages with clear semantic ownership.

7. **Duplicate functionality**
   Search aggressively for duplicated actor, routing, lifecycle, manifest, compiler, Prolog adapter, and execution functionality.
   For every duplicate identify:

   * canonical implementation
   * adapter
   * compatibility layer
   * obsolete implementation
   * candidate for deletion.

8. **Reliability gaps**
   Investigate known weak areas including:

   * RabbitMQ consume/publish ACK/NACK behavior
   * worker/prefetch lifecycle
   * crash recovery
   * replay
   * durable outbox/evidence delivery
   * stale handles/generations
   * lease fencing
   * capability manifests
   * chaos/fault testing
   * transitional `starintel-gserver` / `starlang-prototype` code.

9. **Testing and verification**
   Define tests for language semantics separately from adapter/integration tests.
   Include property/invariant tests where useful.
   Identify semantics suitable for verification with Prolog.

   Important invariants should include things such as:

   * stale actor/runtime handles cannot affect a newer generation
   * stale lease holders cannot commit
   * deterministic source produces deterministic normalized IR/manifests
   * backend selection cannot silently change after materialization
   * recovery cannot duplicate committed effects
   * actor identity/address normalization is canonical.

10. **Developer UX**
    Evaluate whether a Star-Lang program can remain concise and Lisp-like without hiding important runtime behavior.
    Show representative examples for:

    * actor declaration
    * message handler
    * durable actor/job
    * supervised actor
    * expert-system query
    * capability declaration
    * `star://` reference
    * local and remote actor wiring.

Do **not** begin by designing a replacement language from scratch.

First reconstruct what exists, then identify contradictions/gaps, then recommend the minimum coherent architecture.

Deliver:

* `CURRENT-STATE` — what actually exists today
* `SEMANTIC-CORE` — proposed authoritative Star-Lang semantics
* `COMPILER-PIPELINE`
* `RUNTIME-BOUNDARY`
* `ACTOR-MODEL`
* `LOGIC-INTEGRATION`
* `PACKAGE-GRAPH`
* `DUPLICATION-AUDIT`
* `RELIABILITY-GAPS`
* `VERIFICATION-INVARIANTS`
* `MIGRATION-PLAN`
* `OPEN-QUESTIONS`

For the migration plan, give dependency-ordered slices small enough to implement and review individually.

Prefer evidence from the actual codebase and existing Star-Lang/StarIntel specifications over generic programming-language theory. Clearly distinguish observed facts, inferred intent, and recommendations.
