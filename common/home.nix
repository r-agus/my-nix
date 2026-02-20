# common/home.nix
{ config, pkgs, ... }:

{
  home.username = "ruben";
  home.homeDirectory = "/home/ruben";

  # Sincronización declarativa de archivos
  xdg.configFile = {
    "niri".source = ../dotfiles/niri;
    "DankMaterialShell".source = ../dotfiles/DankMaterialShell; 
  };

  # Misma versión que en system.stateVersion
  home.stateVersion = "25.11"; 
}
