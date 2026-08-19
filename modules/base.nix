# Base system configuration: programs, environment, macOS defaults
{
  config,
  pkgs,
  lib,
  userConfig,
  ...
}:
let
  gitPromptScript = ../scripts/git-prompt.sh;
in
{
  home.packages = with pkgs; [
    # Nix tooling
    nixfmt
    nil
    sops
    nixos-generators

    # AI tooling
    llm-agents.codex

    # Development
    # tmux は下の programs.tmux が導入する (single source なのでここには書かない)
    deno
    nodejs
    bun
    python3
    tree

    # Media processing
    ffmpeg
    imagemagick
    poppler
    pandoc # doc-conversion skills

    # Utilities
    fdupes
    fzf
    gws
    yt-dlp
    glow
    ripgrep
    jq # agent scripts parse JSON with bare `jq` (was relying on system /usr/bin/jq)
    himalaya # email skill / scripts/claude/himalaya-mail.sh (was Homebrew-only)

  ];

  programs = {
    git = {
      enable = true;
      settings = {
        user = {
          name = userConfig.gitName;
          email = userConfig.gitEmail;
        };
        init.defaultBranch = "master";
        pull.rebase = true;
      };
      lfs.enable = true;
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      autosuggestion.strategy = [
        "history"
        "completion"
        "match_prev_cmd"
      ];
      syntaxHighlighting.enable = true;
      autocd = true;
      shellAliases = {
        ll = "ls -l";
        la = "ls -la";
        lt = "tree";
        remake = "make -j clean && make -j";
      };
      initContent =
        let
          initExtraBeforeCompInit = lib.mkOrder 550 ''
            # Add completion to fpath
            fpath=(${config.home.homeDirectory}/.docker/completions $fpath)
          '';
          initExtra = lib.mkOrder 1000 ''
            # Source git prompt script
            source ${gitPromptScript}
            GIT_PS1_SHOWUPSTREAM="verbose"
            precmd () { __git_ps1 "%F{cyan}%~%f%F{blue}" "%s %f" }
          '';
        in
        lib.mkMerge [
          initExtraBeforeCompInit
          initExtra
        ];
    };

    # Fish shell: ensures home.sessionVariables are exported in fish too.
    # This does NOT change anyone's default shell (still zsh).
    # Anyone who launches fish interactively gets Nix env vars automatically.
    fish = {
      enable = true;
    };

    # tmux: used by long-lived local sessions and Claude Code launch wrappers.
    # Keep scrollback usable when attaching to existing work.
    tmux = {
      enable = true;
      mouse = true;
      historyLimit = 50000;
      escapeTime = 0; # home-manager 既定の 500ms は nvim の ESC を遅延させるため 0
      terminal = "tmux-256color"; # "screen" だと OSC エスケープが剥ぎ取られ URL がクリック不能になる
      extraConfig = ''
        # OSC 8 ハイパーリンク(クリッカブルURL)を外側ターミナルに透過させる (tmux 3.3+)
        set -g allow-passthrough on
      '';
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };

    gh = {
      enable = true;
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
      withRuby = true;
      withPython3 = true;

      extraPackages = with pkgs; [
        # LSP servers (HLS is project-local via devShell + direnv)
        typescript-language-server
      ];

      plugins = with pkgs.vimPlugins; [
        # Treesitter: grammars pre-built by Nix (no runtime compilation)
        (nvim-treesitter.withPlugins (p: [
          p.haskell
          p.typescript
          p.tsx
          p.javascript
          p.nix
          p.lua
          p.json
          p.yaml
          p.markdown
          p.bash
        ]))

        # Completion
        nvim-cmp
        cmp-nvim-lsp
        cmp-buffer
        cmp-path
        luasnip
        cmp_luasnip

        # Fuzzy finder
        telescope-nvim
        plenary-nvim
      ];

      initLua = ''
        -- Treesitter: grammars pre-built by Nix (withPlugins), auto-start highlight
        vim.api.nvim_create_autocmd('FileType', {
          callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
        })

        -- Completion (nvim-cmp)
        local cmp = require('cmp')
        local luasnip = require('luasnip')
        cmp.setup {
          snippet = {
            expand = function(args) luasnip.lsp_expand(args.body) end,
          },
          mapping = cmp.mapping.preset.insert({
            ['<C-Space>'] = cmp.mapping.complete(),
            ['<CR>'] = cmp.mapping.confirm({ select = true }),
            ['<C-n>'] = cmp.mapping.select_next_item(),
            ['<C-p>'] = cmp.mapping.select_prev_item(),
          }),
          sources = cmp.config.sources(
            { { name = 'nvim_lsp' }, { name = 'luasnip' } },
            { { name = 'buffer' }, { name = 'path' } }
          ),
        }

        -- LSP: vim.lsp.config (Neovim 0.11+ native API, no lspconfig framework)
        local capabilities = require('cmp_nvim_lsp').default_capabilities()

        vim.lsp.config('hls', {
          cmd = { 'haskell-language-server-wrapper', '--lsp' },
          filetypes = { 'haskell', 'lhaskell', 'cabal' },
          root_markers = { 'hie.yaml', 'cabal.project', '*.cabal', 'stack.yaml', 'package.yaml' },
          capabilities = capabilities,
        })

        vim.lsp.config('ts_ls', {
          cmd = { 'typescript-language-server', '--stdio' },
          filetypes = { 'typescript', 'typescriptreact', 'javascript', 'javascriptreact' },
          root_markers = { 'tsconfig.json', 'jsconfig.json', 'package.json' },
          capabilities = capabilities,
        })

        vim.lsp.config('nil_ls', {
          cmd = { 'nil' },
          filetypes = { 'nix' },
          root_markers = { 'flake.nix' },
          capabilities = capabilities,
          settings = { ['nil'] = { formatting = { command = { 'nixfmt' } } } },
        })

        vim.lsp.enable({ 'hls', 'ts_ls', 'nil_ls' })

        -- LSP keybindings
        vim.api.nvim_create_autocmd('LspAttach', {
          callback = function(ev)
            local opts = { buffer = ev.buf }
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
            vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
            vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
            vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
            vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format() end, opts)
            vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
            vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
          end,
        })

        -- Telescope
        local telescope = require('telescope.builtin')
        vim.keymap.set('n', '<leader>ff', telescope.find_files)
        vim.keymap.set('n', '<leader>fg', telescope.live_grep)
        vim.keymap.set('n', '<leader>fb', telescope.buffers)
        vim.keymap.set('n', '<leader>fd', telescope.diagnostics)
      '';
    };
  };

  # VS Code: Nix-managed wrapper to prevent Cursor from hijacking `code`
  home.file.".local/bin/code" = {
    executable = true;
    text = ''
      #!/bin/sh
      exec "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "$@"
    '';
  };

  # Environment variables
  home.sessionVariables = {
    MANPATH = ":/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/share/man";
    # 絶対パスであること。裸の "zsh" だと $SHELL を「実行可能なログインシェル」として
    # 検査・exec するツールが落ちる(実測: Codex Desktop の remote SSH が
    # "requires SHELL to point to an executable login shell" で接続失敗)。
    # 値が zsh なのは意図どおり(対話ログインは fish、エージェント/スクリプトは POSIX 系)。
    SHELL = "/bin/zsh";
    PAGER = "less";
    LESS = "-R";
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    # SCRAPBOX_SID は置かない(2026-07-05 除去): 回転するセッション cookie を公開 repo +
    # world-readable な /nix/store に固定するのが漏洩経路だった。消費側は
    # scrapbox_session.py でsettings/env候補をlive検証し、無効ならfail closedする。
    # gws encryption key in ~/.config/gws/, not macOS Keychain.
    # Why: Keychain ACL blocks GUI-subprocess access (Claude Code / Cursor), forcing re-auth.
    GOOGLE_WORKSPACE_CLI_KEYRING_BACKEND = "file";
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
  ];

  # macOS defaults
  targets.darwin.defaults."com.apple.dock".autohide = true;
  targets.darwin.defaults."com.apple.dock".orientation = "bottom";
  targets.darwin.defaults.NSGlobalDomain.AppleShowAllExtensions = true;
  targets.darwin.defaults."com.apple.finder" = {
    FXPreferredViewStyle = "clmv";
    _FXShowPosixPathInTitle = true;
  };
}
