{
    description = "Deck NixOS configuration";

    inputs = {
        dotfiles.url = "path:../..";
        agents.url = "path:/home/xopc/agents";
    };

    outputs = { dotfiles, agents, ... }: {
        nixosConfigurations.deck = dotfiles.nixosConfigurations.deck.extendModules {
            modules = [
                agents.nixosModules.default
            ];
        };
    };
}
