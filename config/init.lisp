;;;; init.lisp --- trusted Auto Research configuration.
;;;;
;;;; Loaded ONLY by a human operator (scripts/start.lisp). Never from LLM
;;;; output, issue bodies, or HTTP payloads. The DSL splices plists QUOTED,
;;;; so forgejo config must read (:forgejo (:base-url ... :repository ...)).

(in-package :starintel-auto-research)

;;; ------------------------------------------------------------ budgets

(define-budget normal-research)
(define-budget llm-exploration
    :wall-clock-seconds 600)

;;; -------------------------------------------------- research repository

;; The corpus this runtime reads and writes. This repo IS the corpus root
;; (roam/ lives here). Runtime state (ledgers, ARDR transactions, design
;; nodes, research updates) is written here via the semantic tools.
(define-research-repository llm-corpus
  :path (or (let ((root (uiop:getenv "AR_CORPUS_ROOT")))
              (when (and root (plusp (length root))) (pathname root)))
            #p"~/starintel/auto-research-llm-cl/")
  :forgejo (:base-url "https://git.starintel.actor"
            :repository "starintel-labs/auto-research-harness"))

;;; ------------------------------------------------------------ projects

;; Every project names:
;;   REPOSITORY      the source repository being researched (forgejo id)
;;   SOURCE-PATH     its local read-only checkout: repository-* tools read
;;                   HERE, never from the research corpus
;;   RESEARCH-REPOSITORY the research corpus artifacts are written to
;;   PROMPT-PROFILE  prompts/<profile>/ context.md + per-stage files
;;                   (defaults to the project id; files are optional)

(defun ar-source-path (env default)
  "Trusted resolution of a project's local source checkout. The path must
exist: a configured but missing source repository fails at init."
  (let ((value (uiop:getenv env)))
    (let ((path (if (and value (plusp (length value)))
                    (pathname value)
                    default)))
      (unless (uiop:directory-exists-p path)
        (error "configured source path ~s (~a) is not an existing directory"
               (namestring path) env))
      path)))

(define-project auto-research
  :repository "starintel-labs/auto-research-harness"
  :source-path (ar-source-path "AR_HARNESS_SOURCE"
                               #p"~/git/worktrees/auto-research-harness-cl-runtime/")
  :research-repository llm-corpus
  :roam-project "auto-research"
  :prompt-profile "auto-research"
  :budget normal-research)

(define-project prolog-rlm
  :repository "nsaspy/prolog-rlm"
  :source-path (ar-source-path "AR_PROLOG_RLM_SOURCE"
                               #p"~/git/worktrees/prolog-rlm-335/")
  :research-repository llm-corpus
  :roam-project "prolog-rlm"
  :budget llm-exploration)

(define-project star-lang
  :repository "lost-rob0t/star-lang"
  :source-path (ar-source-path "AR_STAR_LANG_SOURCE"
                               #p"~/git/lost-robot/star-lang/")
  :research-repository llm-corpus
  :roam-project "star-lang"
  :prompt-profile "star-lang"
  :budget llm-exploration)

;;; -------------------------------------------------------------- notes

;; Forgejo webhook verification uses FORGEJO_WEBHOOK_SECRET from the
;; environment (fail-closed; unset secret disables the hook).
;;
;; The LLM provider comes from the environment at runtime:
;;   OPENROUTER_API_KEY + AR_MODEL (default openai/gpt-4.1-mini)
;; Without a key the runtime still serves requests; semantic stages fail
;; closed at :unresolved (see ar-run-pending).
;;
;; Principals are configured by scripts/start.lisp from AR_* env tokens.
