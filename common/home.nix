# common/home.nix
{ config, pkgs, lib, ... }:

let
  dotfilesDir = ../dotfiles;
  managedFiles = builtins.attrNames (builtins.readDir dotfilesDir);
in
{
  accounts.email.accounts = {
    "personal" = {
      primary = true;
      realName = "Ruben Agustin";
      address = "r.agussglz@gmail.com";
      userName = "r.agussglz@gmail.com";
      flavor = "gmail.com";
      thunderbird.enable = true;
    };

    "upm" = {
      realName = "Ruben Agustin";
      address = "r.agustin@alumnos.upm.es";
      userName = "r.agustin";

      imap = {
        host = "correo.alumnos.upm.es";
        port = 993;
        tls.enable = true;
      };

      smtp = {
        host = "smtp.upm.es";
        port = 587;
        tls.enable = true;
        tls.useStartTls = true;
      };

      thunderbird.enable = true;
      thunderbird.profiles = [ "principal" ];
    };

    "uc3m" = {
      realName = "Ruben Agustin";
      address = "ruben.agustin@alumnos.uc3m.es";
      userName = "100578484@alumnos.uc3m.es";
      flavor = "gmail.com";
      thunderbird.enable = true;
    };
  };

  home.username = "ruben";
  home.homeDirectory = "/home/ruben";

  home.file = {
    ".face".source = ../dotfiles/avatar.png;
    ".face.icon".source = ../dotfiles/avatar.png;
    ".local/share/typst/packages/local/uni/0.1.0" = {
      source = ./typst-templates/uni; 
      recursive = true; 
    };
  };

  home.packages = with pkgs; [
    vdirsyncer
    rclone
    vesktop
    telegram-desktop
    typst

    grim
    satty
    obs-studio
  ];

  programs.starship = {
     enable = true;
     enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

#    oh-my-zsh = {
#      enable = true;
#      plugins = [ "git" "sudo" "history" ];
#      theme = "robbyrussell";
#    };

    shellAliases = {
      batcare = "echo 80 | sudo tee /sys/devices/platform/lg-laptop/battery_care_limit > /dev/null";
      batlong = "echo 100 | sudo tee /sys/devices/platform/lg-laptop/battery_care_limit > /dev/null";
      batwatch = "cat /sys/devices/platform/lg-laptop/battery_care_limit";
    };

    defaultKeymap = "emacs";

    initContent = ''
      . "$HOME/.cargo/env"
    '';
  };

  programs.git = {
    enable = true;

    settings = {
      user.name  = "Ruben Agustin";
      user.email = "r.agussglz@gmail.com";
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "vim";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.thunderbird = {
    enable = true;
    profiles.principal = {
      isDefault = true;
      extraConfig = ''
        user_pref("mail.smtpserver.smtp_4986247086fa3cd1ffd75cba8eb115e207df8855f768a70ff7e8944c665da376.username", "r.agustin@alumnos.upm.es");
        user_pref("mail.smtpserver.smtp_4986247086fa3cd1ffd75cba8eb115e207df8855f768a70ff7e8944c665da376.authMethod", 3);
      ''; 
    };
  };

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
  };

  systemd.user.services.rclone-gdrive = {
    Unit = {
      Description = "mount Google Drive with rclone";
      After = [ "network-online.target" ]; 
    };
    
    Install = {
      WantedBy = [ "default.target" ];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Drive";

      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount gdrive: %h/Drive \
          --vfs-cache-mode=writes \
          --dir-cache-time=1h \
          --log-level=INFO
      '';
      
      # shutdown 
      ExecStop = "/run/wrappers/bin/fusermount -u %h/Drive";
      
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

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
