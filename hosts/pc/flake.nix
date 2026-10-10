{
    description = "PC NixOS configuration";

    inputs = {
        dotfiles.url = "path:../..";
        agents.url = "git+ssh://git@github.com/xopclabs/agents?ref=main";
        zap.url = "git+ssh://git@github.com/xopclabs/zap?ref=main";
    };

    outputs = { dotfiles, agents, zap, ... }: {
        nixosConfigurations.pc = dotfiles.nixosConfigurations.pc.extendModules {
            modules = [
                agents.nixosModules.default
                { home-manager.extraSpecialArgs.zap = zap; }
            ];
        };
    };
}
