{ config, lib, inputs, ...}:

{
    imports = [ 
        ../../modules/default.nix 
        ./home.nix
        ./sops.nix
        inputs.nix-colors.homeManagerModules.default
        inputs.nixvim.homeModules.nixvim
    ];
    config.modules = {
        theming.stylix.enable = true;

        cli = {
            zsh = {
                enable = true;
                envFile.enable = true;
                envExtra = ''
                # >>> conda initialize >>>
                # !! Contents within this block are managed by 'conda init' !!
                __conda_setup="$('/home/ubuntu/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
                if [ $? -eq 0 ]; then
                    eval "$__conda_setup"
                else
                    if [ -f "/home/ubuntu/miniconda3/etc/profile.d/conda.sh" ]; then
                        . "/home/ubuntu/miniconda3/etc/profile.d/conda.sh"
                    else
                        export PATH="/home/ubuntu/miniconda3/bin:$PATH"
                    fi
                fi
                unset __conda_setup
                # <<< conda initialize <<<
                export CONDA_CHANGEPS1=false
                '';
                initContent = ''
                # Auto-login to CodeArtifact
                aws codeartifact login --tool pip --repository pypi-store --domain $CODEARTIFACT_DOMAIN --domain-owner $ACCOUNT_ID --region $REGION
                aws codeartifact login --tool twine --repository pypi-store --domain $CODEARTIFACT_DOMAIN --domain-owner $ACCOUNT_ID --region $REGION
                '';
            };
            tmux = {
                enable = true;
                statusPosition = "bottom";
                prefixKey = "C-Space";
            };
            starship = {
                enable = true;
                aws.enable = true;
            };
            eza.enable = true;
            zoxide.enable = true;
            bat.enable = true;
            fzf.enable = true;
        };

        tools = {
            git.enable = true;
            awscli.enable = true;
            btop.enable = true;
            nh.enable = true;
            tldr.enable = true;
            scripts.enable = true;
        };

        fileManagers.yazi.enable = true;

        desktop.other.xdg.enable = true;

        packages.common.enable = true;
    };
    config.colorScheme = inputs.nix-colors.colorSchemes.nord;
}
