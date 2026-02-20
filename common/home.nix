# common/home.nix
{ config, pkgs, lib, ... }:

let
  dotfilesDir = ../dotfiles;
  managedFiles = builtins.attrNames (builtins.readDir dotfilesDir);
in
{
  home.username = "ruben";
  home.homeDirectory = "/home/ruben";

  home.file = {
    ".face".source = ../dotfiles/avatar.png;
    ".face.icon".source = ../dotfiles/avatar.png;
  };

  # mapea todo dotfiles
  xdg.configFile = lib.genAttrs managedFiles (name: {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/${name}";
  });

  # Misma versión que en system.stateVersion
  home.stateVersion = "25.11"; 
}
