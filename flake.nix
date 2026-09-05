{
  description = "Auto Research corpus + launcher (research CLI, trusted init, prompt profiles, roam corpus)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;

        # Same Common Lisp library set as the runtime flake: the daemon
        # loads the runtime ASDF systems from AR_RUNTIME_SOURCE at start.
        clDeps = with pkgs.sbcl.pkgs; [
          alexandria
          serapeum
          str
          cl-ppcre
          jzon
          babel
          hunchentoot
          dexador
          quri
          uuid
          local-time
          split-sequence
          ironclad
          bordeaux-threads
          fiveam
        ];

        sbcl = pkgs.sbcl.withPackages (ps: clDeps);

        launcherDeps = [
          pkgs.bash
          pkgs.curl
          pkgs.python3
          pkgs.git
        ];

        daemonDeps = [
          sbcl
          pkgs.swi-prolog
          pkgs.curl
          pkgs.python3
          pkgs.git
        ];

        corpusShare = dir: ''
          share="$out/share/auto-research-corpus"
          mkdir -p "$share"
          for entry in bin config prompts roam scripts env.example; do
            cp -R "$src/$entry" "$share/"
          done
        '';

        # The launcher: bin/research with its runtime dependencies on PATH.
        # The live corpus stays where AR_CORPUS_ROOT points (default
        # ~/starintel/auto-research-llm-cl); the installed share copy is a
        # read-only fallback, never the mutable corpus.
        research = pkgs.stdenvNoCC.mkDerivation {
          pname = "auto-research-research";
          version = "0.1.0";
          src = lib.cleanSource ./.;

          strictDeps = true;
          nativeBuildInputs = [
            pkgs.bash
            pkgs.makeWrapper
          ];

          dontConfigure = true;
          dontBuild = true;

          doCheck = true;
          checkPhase = ''
            runHook preCheck
            bash -n bin/research
            bash tests/test-launcher.bash
            runHook postCheck
          '';

          installPhase = ''
            runHook preInstall
            ${corpusShare "research"}
            install -Dm 0755 "$src/bin/research" "$out/bin/research"
            wrapProgram "$out/bin/research" \
              --prefix PATH : ${lib.makeBinPath launcherDeps} \
              --set-default AR_CORPUS_ROOT "$share"
            runHook postInstall
          '';

          meta = {
            description = "Auto Research launcher (research CLI) for the local corpus runtime";
            license = lib.licenses.agpl3Only;
            mainProgram = "research";
            platforms = lib.platforms.unix;
          };
        };

        # The daemon wrapper: starts the CL runtime against a corpus. The
        # runtime ASDF systems come from AR_RUNTIME_SOURCE (trusted env);
        # swipl is taken from PROLOG_RLM_SWIPL or PATH.
        autoResearchDaemon = pkgs.stdenvNoCC.mkDerivation {
          pname = "auto-research-daemon";
          version = "0.1.0";
          src = lib.cleanSource ./.;

          strictDeps = true;
          nativeBuildInputs = [
            pkgs.bash
            pkgs.makeWrapper
          ];

          dontConfigure = true;
          dontBuild = true;

          installPhase = ''
            runHook preInstall
            ${corpusShare "daemon"}
            mkdir -p "$out/bin"
            cat > "$out/bin/.auto-research-daemon-unwrapped" <<EOF
            #!${pkgs.runtimeShell}
            set -euo pipefail
            corpus="\''${AR_CORPUS_ROOT:-$HOME/starintel/auto-research-llm-cl}"
            export PROLOG_RLM_SWIPL="\''${PROLOG_RLM_SWIPL:-$(command -v swipl || true)}"
            cd "\$corpus"
            exec ${sbcl}/bin/sbcl --noinform --script scripts/start.lisp "\$@"
            EOF
            install -m 0755 "$out/bin/.auto-research-daemon-unwrapped" "$out/bin/auto-research-daemon"
            wrapProgram "$out/bin/auto-research-daemon" \
              --prefix PATH : ${lib.makeBinPath daemonDeps}
            runHook postInstall
          '';

          meta = {
            description = "Auto Research daemon wrapper (CL runtime against the corpus)";
            license = lib.licenses.agpl3Only;
            mainProgram = "auto-research-daemon";
            platforms = lib.platforms.unix;
          };
        };

        check = pkgs.stdenvNoCC.mkDerivation {
          pname = "auto-research-corpus-check";
          version = "0.1.0";
          src = lib.cleanSource ./.;
          dontConfigure = true;
          dontBuild = true;
          doCheck = true;
          nativeBuildInputs = [ pkgs.bash ];
          checkPhase = ''
            runHook preCheck
            bash -n bin/research
            bash tests/test-launcher.bash
            runHook postCheck
          '';
          installPhase = ''
            runHook preInstall
            mkdir "$out"
            runHook postInstall
          '';
        };
      in
      {
        packages = {
          default = research;
          inherit
            research
            autoResearchDaemon
            check
            ;
        };

        apps = {
          default = {
            type = "app";
            program = "${research}/bin/research";
          };
          daemon = {
            type = "app";
            program = "${autoResearchDaemon}/bin/auto-research-daemon";
          };
        };

        checks.default = check;

        devShells.default = pkgs.mkShell {
          packages = daemonDeps;

          shellHook = ''
            export AR_CORPUS_ROOT="''${AR_CORPUS_ROOT:-$HOME/starintel/auto-research-llm-cl}"
            export AR_RUNTIME_SOURCE="''${AR_RUNTIME_SOURCE:-$HOME/git/worktrees/auto-research-harness-cl-runtime/}"
            export PROLOG_RLM_SWIPL="''${PROLOG_RLM_SWIPL:-$(command -v swipl)}"
            echo "auto-research dev shell: corpus=$AR_CORPUS_ROOT runtime=$AR_RUNTIME_SOURCE"
            echo "research CLI: ./bin/research (start the daemon with: research start)"
          '';
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
