{ config, lib, inputs, ...}:

let
    username = "pleyba";
in
{
    home = {
        username = username;
        homeDirectory = "/home/${username}";
    };
    
    # Let home-manager manage itself
    programs.home-manager.enable = true;
}
