{ config, lib, pkgs, ... }:

with lib;
let
    cfg = config.homelab.ollama;

    ollamaPackage = {
        cpu = pkgs.ollama-cpu;
        cuda = pkgs.ollama-cuda;
        rocm = pkgs.ollama-rocm;
        vulkan = pkgs.ollama-vulkan;
    }.${cfg.acceleration};
in
{
    options.homelab.ollama = {
        enable = mkEnableOption "Ollama local LLM API (OpenAI-compatible)";

        subdomain = mkOption {
            type = types.str;
            description = "Subdomain for Ollama (Traefik)";
            example = "ollama.vm.local";
        };

        acceleration = mkOption {
            type = types.enum [ "cpu" "cuda" "rocm" "vulkan" ];
            default = "cuda";
            description = ''
                Hardware backend for inference. Use `cuda` on NVIDIA (homelab GPU),
                `cpu` if the VM has no GPU passthrough.
            '';
        };

        modelsDir = mkOption {
            type = types.nullOr types.path;
            default = null;
            example = "/mnt/raid_pool/ollama/models";
            description = ''
                Directory for model weights. When null, uses
                `services.ollama` default under `/var/lib/ollama`.
            '';
        };

        loadModels = mkOption {
            type = types.listOf types.str;
            default = [ "qwen2.5:3b" ];
            description = ''
                Models to pull on boot (`ollama pull`). See
                https://ollama.com/library
            '';
        };

        syncModels = mkOption {
            type = types.bool;
            default = false;
            description = ''
                Remove installed models that are not listed in `loadModels`.
            '';
        };

        openFirewall = mkOption {
            type = types.bool;
            default = false;
            description = "Open Ollama port on the host firewall (usually unnecessary behind Traefik)";
        };
    };

    config = mkIf cfg.enable {
        systemd.tmpfiles.rules = lib.optionals (cfg.modelsDir != null) [
            "d ${cfg.modelsDir} 0750 ollama ollama -"
        ];

        services.ollama = {
            enable = true;
            package = ollamaPackage;
            host = "127.0.0.1";
            user = "ollama";
            group = "ollama";
            inherit (cfg) loadModels syncModels openFirewall;
            models = lib.mkIf (cfg.modelsDir != null) cfg.modelsDir;
        };

        homelab.traefik.routes = mkIf config.homelab.traefik.enable [
            {
                name = "ollama";
                subdomain = cfg.subdomain;
                backendUrl = "http://127.0.0.1:${toString config.services.ollama.port}";
            }
        ];

        homelab.glance.services = mkIf config.homelab.glance.enable [
            {
                title = "Ollama";
                subdomain = cfg.subdomain;
                icon = "mdi:robot-outline";
                group = "Other";
            }
        ];
    };
}
