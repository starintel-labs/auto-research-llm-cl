# Star-Lang project profile (context for every stage)

Star-Lang is a Common Lisp-only language/runtime investigated through this
harness. Scope constraints that hold for every research and design stage:

- Common Lisp owns the `.star` parser, source locations/origin chains,
  semantic validation, normalized IR, canonical manifests, lifecycle,
  delivery, deterministic dispatch, recovery, document construction,
  direct execution, optional cl-gserver integration, and public API.
- There must be ONE semantic authority: duplicated actor/runtime/compiler
  semantics across packages are findings to record, not patterns to copy.
- The transitional `starlang-prototype` is expected to decompose into
  dependency-ordered ASDF systems; treat it as transitional evidence.
- Star addressing is hierarchical RFC 3986-style:
  `star://<authority>/<resource-kind>/<resource-path>`.
- Logic/expert-system integration is adapter-based (`swi-prolog`, `lisa`,
  `n-prolog`); `:backend auto` must resolve deterministically once.
- Do not propose rewriting the compiler/runtime outside Common Lisp.

Evidence rules: every finding must cite a file, symbol, commit, or
document of the star-lang repository (or an existing roam research node).
Record contradictions explicitly as counterevidence.
