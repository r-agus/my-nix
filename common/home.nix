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
    inherit name;
    value = { source = "${dotfilesDir}/${name}"; };
  }) managedFiles);

  # Misma versión que en system.stateVersion
  home.stateVersion = "25.11"; 
}
