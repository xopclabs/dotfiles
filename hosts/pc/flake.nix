{
    description = "PC NixOS configuration";

    inputs = {
        dotfiles.url = "path:../..";
        agents.url = "path:/home/xopc/agents";
    };

    outputs = { dotfiles, agents, ... }: {
        nixosConfigurations.pc = dotfiles.nixosConfigurations.pc.extendModules {
            modules = [
                agents.nixosModules.default
            ];
        };
    };
}
