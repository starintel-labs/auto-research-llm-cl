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

(define-project auto-research
  :repository "starintel-labs/auto-research-harness"
  :research-repository llm-corpus
  :roam-project "auto-research"
  :budget normal-research)

(define-project prolog-rlm
  :repository "nsaspy/prolog-rlm"
  :research-repository llm-corpus
  :roam-project "prolog-rlm"
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
