# common/home.nix
{ config, pkgs, lib, inputs, ... }:

let
  dotfilesDir = ../dotfiles;
  managedFiles = builtins.attrNames (builtins.readDir dotfilesDir);
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./social.nix
    inputs.spicetify-nix.homeManagerModules.default
  ];

  home.username = "ruben";
  home.homeDirectory = "/home/ruben";

  home.file = {
    ".face".source = ../dotfiles/avatar.png;
    ".face.icon".source = ../dotfiles/avatar.png;
    # Ajustes para que se vea bien en modo oscuro/claro según prefieras
    ".local/share/typst/packages/local/uni/0.1.0" = {
      source = ./typst-templates/uni;
      recursive = true;
    };
    ".certificates/ruben.p12".source = config.lib.file.mkOutOfStoreSymlink "/run/secrets/certificado_digital";
  };

  home.packages = with pkgs; [
    rclone
    typst
    neovim
    neovide
    jetbrains.idea
    pkgs.zed-editor
    pkgs.brave
    ventoy
    pdfpc

    grim
    satty
    obs-studio
    (lib.hiPrio (pkgs.writeShellScriptBin "davinci-resolve" ''
      export QT_QPA_PLATFORM=xcb
      exec ${pkgs.davinci-resolve}/bin/davinci-resolve "$@"
    ''))
    davinci-resolve

    kdePackages.okular
    inputs.autofirma-nix.packages.${pkgs.stdenv.hostPlatform.system}.autofirma

    spotube
    freetube

    inputs.codex-cli-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.llm-agents.packages.${pkgs.system}.antigravity-cli
    inputs.llm-agents.packages.${pkgs.system}.claw-code
  ];

  targets.genericLinux.nixGL.vulkan.enable = true;

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  programs.starship = {
     enable = true;
     enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      batcare = "echo 80 | sudo tee /sys/devices/platform/lg-laptop/battery_care_limit > /dev/null";
      batlong = "echo 100 | sudo tee /sys/devices/platform/lg-laptop/battery_care_limit > /dev/null";
      batwatch = "cat /sys/devices/platform/lg-laptop/battery_care_limit";
      davinci-resolve = "QT_QPA_PLATFORM=xcb davinci-resolve";
    };

    defaultKeymap = "emacs";
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

  programs.zathura = {
    enable = true;
    options = {
      recolor = "true";
      recolor-keep-true-color = "true";
      selection-clipboard = "clipboard";
    };
  };

  programs.spicetify = {
    enable = true;

    theme = spicePkgs.themes.catppuccin;
    colorScheme = "mocha";
    enabledExtensions = with spicePkgs.extensions; [
      adblock
      hidePodcasts
      shuffle
      fullAppDisplay
    ];
  };

  programs.mpv = {
    enable = true;

    config = {
      profile = "gpu-hq";
      vo = "gpu-next";
      hwdec = "auto-safe";
      ytdl-format = "bestvideo+bestaudio";
    };

    scripts = with pkgs.mpvScripts; [
      mpris
      # thumbfast
    ];
  };

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
  };

  services.kanshi = {
    enable = true;
    systemdTarget = "graphical-session.target";
  };

  # services.openvpn

  services.ollama = {
    enable = true;
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

  systemd.user.services.rclone-nextcloud = {
    Unit = {
      Description = "mount Nextcloud with rclone";
      After = [ "network-online.target" ];
    };

    Install = {
      WantedBy = [ "default.target" ];
    };

    Service = {
      Type = "notify";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %h/Nextcloud";

      ExecStart = ''
        ${pkgs.rclone}/bin/rclone mount nextcloud: %h/Nextcloud \
          --vfs-cache-mode=writes \
          --dir-cache-time=1h \
          --log-level=INFO
      '';

      # shutdown
      ExecStop = "/run/wrappers/bin/fusermount -u %h/Nextcloud";

      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  xdg.configFile = lib.genAttrs managedFiles (name: {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nixos-config/dotfiles/${name}";
  });

  # Misma versión que en system.stateVersion
  home.stateVersion = "25.11";
}
