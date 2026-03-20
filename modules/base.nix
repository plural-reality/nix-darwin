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
    llm-agents.openclaw

    # Development
    tmux
    deno
    nodejs
    bun
    python3
    tree

    # Media processing
    ffmpeg
    imagemagick
    poppler

    # Utilities
    fdupes
    fzf
    yt-dlp
    glow
    ripgrep
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
        filter.lfs = {
          process = "git-lfs filter-process";
          required = true;
          clean = "git-lfs clean -- %f";
          smudge = "git-lfs smudge -- %f";
        };
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

      extraPackages = with pkgs; [
        # LSP servers (HLS is project-local via devShell + direnv)
        nodePackages.typescript-language-server
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
    SHELL = "zsh";
    PAGER = "less";
    LESS = "-R";
    SOPS_AGE_KEY_FILE = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    SCRAPBOX_SID = "s:SHE-0nIW3e5263L9Hm4BeQf0aRSSQpFC.uVtaUJ7Wwu+6HtCS8tPE7Zb0CuAlLCtmNMWUGWp49Yo";
    CLAUDE_CODE_EFFORT_LEVEL = "max";
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
