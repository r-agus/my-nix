{ config, pkgs, ... }:

{
  sops.secrets.ai_agents_env = {
    sopsFile = ./secrets.yaml;
    owner = "ruben";
    mode = "0400";
  };
}
