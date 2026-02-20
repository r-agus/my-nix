# common/home.nix
{ config, pkgs, ... }:

let
  dotfilesDir = ../dotfiles;
  managedFiles = builtins.attrNames (builtins.readDir dotfilesDir);
in
{
  home.username = "ruben";
  home.homeDirectory = "/home/ruben";

  # mapea todo dotfiles
  xdg.configFile = builtins.listToAttrs (map (name: {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/${name}";
  }) managedFiles);

  # Misma versión que en system.stateVersion
  home.stateVersion = "25.11"; 
}
