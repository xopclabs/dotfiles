{
    description = "PC NixOS configuration";

    inputs = {
        dotfiles.url = "path:../..";
        agents.url = "git+ssh://git@github.com/xopclabs/agents?ref=main";
    };

    outputs = { dotfiles, agents, ... }: {
        nixosConfigurations.pc = dotfiles.nixosConfigurations.pc.extendModules {
            modules = [
                agents.nixosModules.default
            ];
        };
    };
}
