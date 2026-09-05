;;;; start.lisp --- start the Auto Research web runtime against this corpus.
;;;;
;;;; Trusted init only: reads config/init.lisp and env tokens from the
;;;; operator environment. Never accepts configuration from LLM output,
;;;; issue bodies, or HTTP payloads.
;;;;
;;;; Usage: sbcl --script scripts/start.lisp
;;;; Env:   see env.example

(require :asdf)

(defun ar-env (name default)
  (let ((value (uiop:getenv name)))
    (if (and value (plusp (length value))) value default)))

(let ((quicklisp (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname))))
  (when (probe-file quicklisp)
    (load quicklisp)))

;; the CL systems live in the runtime source checkout
(asdf:initialize-source-registry
 `(:source-registry (:tree ,(ar-env "AR_RUNTIME_SOURCE"
                                    "/home/unseen/git/worktrees/auto-research-harness-cl-runtime/"))
                    :inherit-configuration))

(asdf:load-system :starintel-auto-research-web)

(in-package :starintel-auto-research)

;; the same env accessor, now inside the runtime package (the earlier
;; CL-USER copy is used by the source-registry init above)
(defun ar-env (name default)
  (let ((value (uiop:getenv name)))
    (if (and value (plusp (length value))) value default)))

(defun build-provider ()
  "A real provider only when OPENROUTER_API_KEY is set; otherwise nil so
semantic stages fail closed instead of reaching for credentials."
  (let ((key (uiop:getenv "OPENROUTER_API_KEY")))
    (when (and key (plusp (length key)))
      (rlm:make-provider
       :endpoint (ar-env "AR_LLM_ENDPOINT"
                         "https://openrouter.ai/api/v1/chat/completions")
       :model (ar-env "AR_MODEL" "openai/gpt-4.1-mini")
       :credential-env "OPENROUTER_API_KEY"))))

(defun configure-principals ()
  "Operator token: full v1 capabilities. Readonly token: read-only.
Tokens come from AR_OPERATOR_TOKEN / AR_READONLY_TOKEN; defaults exist for
local development only."
  (let ((operator-token (ar-env "AR_OPERATOR_TOKEN" "dev-operator-token"))
        (readonly-token (ar-env "AR_READONLY_TOKEN" "dev-readonly")))
    (starintel-auto-research-web:configure-principal
     operator-token
     (research-core:make-principal
      "operator"
      (list :|research:read| :|research:submit| :|research:cancel|
            :|research:approve| :|design:approve| :|runtime:inspect|)))
    (starintel-auto-research-web:configure-principal
     readonly-token
     (research-core:make-principal "readonly" (list :|research:read|)))))

;; trusted configuration (budgets, repositories, projects)
(load (merge-pathnames "config/init.lisp" (uiop:getcwd)))

;; the corpus root; this repo IS the corpus
(defparameter *corpus-root*
  (truename (ar-env "AR_CORPUS_ROOT" (uiop:getcwd))))

(ensure-roam-layout *corpus-root*)

(defparameter *runtime*
  (make-ar-runtime *corpus-root*
                   :provider (build-provider)
                   :operator "auto-research-local"))

(configure-principals)

(setf starintel-auto-research-web:*runtime* *runtime*)

(let ((port (parse-integer (ar-env "AR_WEB_PORT" "8080")))
      (address (ar-env "AR_WEB_ADDRESS" "127.0.0.1")))
  (starintel-auto-research-web:start-api :port port :address address)
  (format t "~&auto-research: corpus ~a~%" *corpus-root*)
  (format t "~&auto-research: provider ~a~%"
          (if (build-provider)
              (ar-env "AR_MODEL" "openai/gpt-4.1-mini")
              "none (semantic stages fail closed)"))
  (format t "~&auto-research: API on http://~a:~a/api/v1~%" address port)
  (finish-output)
  ;; serve until interrupted
  (loop (sleep 60)))
