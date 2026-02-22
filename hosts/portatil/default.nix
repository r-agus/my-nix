{ ... }:
{
  imports = [
    ./hardware.nix
    ../../common/base.nix
    ../../common/network.nix
  ];

  sops.defaultSopsFile = ./secrets.yaml;

  services.upower.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  my.vpn.ipv4 = "10.10.20.2/24";
  networking.hostName = "Portatil-nixos";

  home-manager.users.ruben = {
    services.kanshi.settings = [
      {
        profile.name = "portatil";
        profile.outputs = [
          { criteria = "eDP-1"; status = "enable"; }
        ];
      }
      {
        profile.name = "casa";
        profile.outputs = [
          { criteria = "eDP-1"; status = "disable"; }
          { criteria = "HDMI-A-1"; status = "enable"; }
        ];
      }
    ];
  };
}
