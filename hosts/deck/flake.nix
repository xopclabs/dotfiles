{
    description = "Deck NixOS configuration";

    inputs = {
        dotfiles.url = "path:../..";
        agents.url = "git+ssh://git@github.com/xopclabs/agents?ref=main";
    };

    outputs = { dotfiles, agents, ... }: {
        nixosConfigurations.deck = dotfiles.nixosConfigurations.deck.extendModules {
            modules = [
                agents.nixosModules.default
            ];
        };
    };
}
