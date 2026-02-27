# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.dms.nixosModules.default # O inputs.dms.nixosModules.greeter
  ];

  # Use the GRUB 2 boot loader.
  # boot.loader.grub.enable = true;
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # Define on which hard drive you want to install Grub.
  # boot.loader.grub.device = "/dev/sda"; # or "nodev" for efi only

  # Use systemd boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Configure network connections interactively with nmcli or nmtui.
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    font-awesome
    nerd-fonts.jetbrains-mono
    nerd-fonts.fira-code
    nerd-fonts.symbols-only
  ];

  fonts.fontDir.enable = true;

  console.keyMap = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # services.pulseaudio.enable = true;
  # OR
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  environment.shells = with pkgs; [ zsh ];

  environment.etc."xdg/menus/gnome-applications.menu".source = "${pkgs.gnome-menus}/etc/xdg/menus/gnome-applications.menu";

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "niri"; 
    XDG_MENU_PREFIX = "gnome-";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "niri";
    # RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
    DEFAULT_BROWSER = "${pkgs.kdePackages.dolphin}/bin/dolphin";
    # QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  environment.variables = { 
    EDITOR =  "vim"; 
    GTK_THEME = "Adwaita:dark";
    GTK_APPLICATION_PREFER_DARK_THEME = "1";
    QT_QPA_PLATFORM = "wayland";
  };

  environment.systemPackages = with pkgs; [
    vim # Nano editor also installed by default
    wget
    git
    gh
    wl-clipboard
    adwaita-icon-theme
    gnome-themes-extra
    gsettings-desktop-schemas
    pavucontrol
    cups-pk-helper
 
    p7zip
    unrar
    unzip

    localsend

    vscode
    inputs.antigravity-nix.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    # rustup
    # gcc
    stlink

    # Dolphin y qt
    kdePackages.dolphin
    kdePackages.kio
    kdePackages.breeze
    kdePackages.breeze-icons
    kdePackages.qtwayland
    kdePackages.gwenview
    kdePackages.ark
    kdePackages.qt6ct
    libsForQt5.qt5ct
    kdePackages.kservice
    kdePackages.kio-extras
    shared-mime-info
    desktop-file-utils
    libsForQt5.qtstyleplugins
    kdePackages.partitionmanager
    # gnome-menus # just to find packages, 500KB approx

    udisks
    usbutils
  ];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.ruben = {
     isNormalUser = true;
     shell = pkgs.zsh;
     extraGroups = [ "networkmanager" "wheel" "video" ]; # Enable ‘sudo’ for the user.
     initialPassword = "password";
     homeMode = "711";
     packages = with pkgs; [
       tree
       kitty
     ];
   };

  programs.zsh.enable = true;
  programs.dconf.enable = true;
  programs.firefox.enable = true;
  programs.yazi.enable = true;

  programs.dms-shell = {
    enable = true;
    package = inputs.dms.packages.${pkgs.stdenv.hostPlatform.system}.default;

    systemd = {
      enable = true;
      restartIfChanged = true;
    };

    enableSystemMonitoring = true;     # System monitoring widgets (dgop)
    enableVPN = true;                  # VPN management widget
    enableDynamicTheming = true;       # Wallpaper-based theming (matugen)
    enableAudioWavelength = true;      # Audio visualizer (cava)
    enableCalendarEvents = true;       # Calendar integration (khal)
    enableClipboardPaste = true;       # Pasting from the clipboard history (wtype) 
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "ventoy-1.1.10"
    ];
  };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.settings.auto-optimise-store = true;
  hardware.graphics.enable = true;
  hardware.brillo.enable = true;

  # Niri
  programs.niri.enable = true;
  programs.niri.package = inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.default;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-gnome
    ];
  }; 

  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
    "application/x-directory" = "org.kde.dolphin.desktop";
    "x-scheme-handler/file" = "org.kde.dolphin.desktop";
  };
  
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  services.resolved.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
      layout = "us";
      variant = "altgr-intl";
  };
  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.flatpak.enable = true;
  services.udev.packages = [ pkgs.stlink ];

  services.syncthing = {
    enable = true;
    user = "ruben";
    dataDir = "/home/ruben";
    configDir = "/home/ruben/.config/syncthing";
    openDefaultPorts = true;
  };

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
  };

  security.polkit.enable = true;
  security.rtkit.enable = true;

  systemd.user.services.polkit-kde-authentication-agent-1 = {
    description = "polkit-kde-authentication-agent-1";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.kdePackages.polkit-kde-agent-1}/libexec/polkit-kde-authentication-agent-1";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  # Rebuild sycoca db 
  system.userActivationScripts.kbuildsycoca = {
    text = ''
      mkdir -p $HOME/.local/share/applications
      if [ -x "${pkgs.kdePackages.kservice}/bin/kbuildsycoca6" ]; then
        ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental --global 2>/dev/null || true
      fi

      if [ -x "${pkgs.kdePackages.kservice}/bin/kbuildsycoca6" ]; then
         ${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental --global 2>/dev/null || true
      fi
    '';
  };

  # Open ports in the firewall.
  # Localsend
  networking.firewall.allowedTCPPorts = [ 53317 ];
  # Localsend, wireguard
  networking.firewall.allowedUDPPorts = [ 53317 51820 ];

  sops.secrets.google_client_id = {
    sopsFile = ./secrets.yaml;
    owner = config.users.users.ruben.name;
  };
  
  sops.secrets.google_client_secret = {
    sopsFile = ./secrets.yaml;
    owner = config.users.users.ruben.name;
  };

  sops.secrets."rclone_conf" = {
    sopsFile = ./secrets.yaml;
    owner = config.users.users.ruben.name;
    group = config.users.users.ruben.group;
    path = "/home/ruben/.config/rclone/rclone.conf";
  };
  
  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  system.stateVersion = "25.11"; # Did you read the comment?
}

