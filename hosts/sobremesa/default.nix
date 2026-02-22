{ config, ... }:
{
  imports = [
    ./hardware.nix
    ../../common/base.nix
    ../../common/network.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  my.vpn.ipv4 = "10.10.20.3/24";
  networking.hostName = "PC-nixos";

  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false; # GTX 1060: Use nvidia old drivers (propertary)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  home-manager.users.ruben = { pkgs, ... }: {
    services.swayidle = {
      enable = true;
      events = {
        before-sleep = "/run/current-system/sw/bin/dms ipc call lock lock";
      };
      timeouts = [
        {
          timeout = 240; 
          command = "${pkgs.kitty}/bin/kitty --class screensaver -e ${pkgs.cmatrix}/bin/cmatrix -abs";
        }
        {
          timeout = 300; 
          command = "/run/current-system/sw/bin/dms ipc call lock lock";
        }
        {
          timeout = 600; 
          command = "${pkgs.niri}/bin/niri msg action power-off-monitors";
          resumeCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
        }
        {
          timeout = 1800; 
          command = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];
    };
  };
}
