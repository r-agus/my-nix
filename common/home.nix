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

  home.packages = with pkgs; [
    vdirsyncer
  ];

  xdg.configFile = (lib.genAttrs managedFiles (name: {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/${name}";
  })) // {
    "vdirsyncer/config".text = ''
      [general]
      status_path = "~/.local/share/vdirsyncer/status/"

      [pair my_google]
      a = "google_calendar"
      b = "local_calendar"
      collections = ["from a", "from b"]

      [storage google_calendar]
      type = "google_calendar"
      token_file = "~/.local/share/vdirsyncer/google_token"
      client_id.fetch = ["command", "cat", "/run/secrets/google_client_id"]
      client_secret.fetch = ["command", "cat", "/run/secrets/google_client_secret"]

      [storage local_calendar]
      type = "filesystem"
      path = "~/.calendars/google/"
      fileext = ".ics"
    '';

    "khal/config".text = ''
      [calendars]
      [[google]]
      path = ~/.calendars/google/
      type = discover

      [locale]
      timeformat = %H:%M
      dateformat = %d/%m/%Y
      longdateformat = %d/%m/%Y
      datetimeformat = %d/%m/%Y %H:%M
      longdatetimeformat = %d/%m/%Y %H:%M
    '';
  }; 

  # Misma versión que en system.stateVersion
  home.stateVersion = "25.11"; 
}
