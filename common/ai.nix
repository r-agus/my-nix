{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  services.hermes-agent = {
    enable = true;
    settings = {
      model = {
        provider = "openai-codex";
        default = "gpt-6.1-sol";
      };
      agent.reasoning_effort = "medium";
    };
    addToSystemPackages = true;
    environmentFiles = [ config.sops.secrets.ai_agents_env.path ];
  };

  users.users.ruben.extraGroups = [ "hermes" ];

  sops.secrets.ai_agents_env = {
    sopsFile = ./secrets.yaml;
    owner = "ruben";
    mode = "0400";
  };
}
