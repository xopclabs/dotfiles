{  lib, config, pkgs, ... }:
with lib;
let
    cfg = config.modules.nvim;
    # Source my theme
    nordtheme = pkgs.vimUtils.buildVimPlugin {
        name = "";
        src = pkgs.fetchFromGitHub {
            owner = "shaunsingh";
            repo = "nord.nvim";
            rev = "80c1e5321505aeb22b7a9f23eb82f1e193c12470";
            sha256 = "sha256-8uPbkaJBXsOGeYCyXSO/aMzf87PE5McwZeww4eoYZy8=";
        };
    };
in {
    options.modules.nvim = { enable = mkEnableOption "nvim"; };
    config = mkIf cfg.enable {

        home.file.".config/nvim/settings.lua".source = ./init.lua;
        
        home.packages = with pkgs; [
            rnix-lsp nixfmt # Nix
            lua-language-server stylua # Lua
        ];

        programs.zsh = {
            initExtra = ''
                export EDITOR="nvim"
            '';

            shellAliases = {
                vim = "nvim -i NONE";
            };
        };

        programs.neovim = {
            enable = true;
            plugins = with pkgs.vimPlugins; [ 
                vim-nix
                plenary-nvim
                {
                    plugin = nordtheme;
                    config = "colorscheme nord";
                }
                {
                    plugin = impatient-nvim;
                    config = "lua require('impatient')";
                }
                {
                    plugin = lualine-nvim;
                    config = "lua require('lualine').setup()";
                }
                {
                    plugin = telescope-nvim;
                    config = "lua require('telescope').setup()";
                }
                {
                    plugin = nvim-lspconfig;
                    config = ''
                        lua << EOF
                        require('lspconfig').rust_analyzer.setup{}
                        require('lspconfig').lua_ls.setup{}
                        require('lspconfig').rnix.setup{}
                        require('lspconfig').zk.setup{}
                        EOF
                    '';
                }
                {
                    plugin = nvim-treesitter;
                    config = ''
                    lua << EOF
                    require('nvim-treesitter.configs').setup {
                        highlight = {
                            enable = true,
                            additional_vim_regex_highlighting = false,
                        },
                    }
                    EOF
                    '';
                }
            ];

            extraConfig = ''
                luafile ~/.config/nvim/settings.lua
            '';
        };
    };
}
