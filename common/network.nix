{ config, lib, ... }:

{
  options.my.vpn.ipv4 = lib.mkOption {
    type = lib.types.str;
    description = "Dirección IPv4 local para la VPN WireGuard";
  };

  config = {
    sops.secrets.wg_private_key = {};
    sops.secrets.wg_endpoint = {
      sopsFile = ./secrets.yaml;
    };

    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    sops.templates."wg0.nmconnection" = {
      path = "/etc/NetworkManager/system-connections/wg0.nmconnection";
      owner = "root";
      group = "root";
      mode = "0600"; # Requisito estricto de NetworkManager
      content = ''
        [connection]
        id=wg0
        type=wireguard
        interface-name=wg0
        autoconnect=false

        [wireguard]
        listen-port=51820
        mtu=1280
        private-key=${config.sops.placeholder.wg_private_key}

        [wireguard-peer.YU1zkPVGGXJpekeCfqS++Yg2tgCUPG54+Y7HC3Bmthk=]
        endpoint=${config.sops.placeholder.wg_endpoint}:51820
        allowed-ips=10.10.10.0/28;10.10.20.0/24;10.10.30.0/24;
        persistent-keepalive=25

        [ipv4]
        method=manual
        address1=${config.my.vpn.ipv4}
        dns=10.10.20.1;
        dns-search=~home.lab;

        [ipv6]
        method=disabled
      '';
    };
  };
}
