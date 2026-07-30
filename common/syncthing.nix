{ config, lib, ... }:

let
  cfg = config.my.syncthing;

  devices = {
    portatil = {
      id = "5XN4WYQ-A2ZRFFK-7RU7TVH-I5NIUVZ-CUTMB5H-S4UPBYU-DLLFQI4-H7TP3A4";
    };
    sobremesa = {
      id = "D5DIMUA-RQBDQYJ-ZMDP5RH-77IUYAU-X4CGVXD-3ZJ4RHT-IFKSXP2-YSNH2AX";
    };
    homeserver = {
      id = "NYOJ3DT-RGO2GSR-OO4A7VJ-AYVL5NR-VC6HMYO-7W75ZIE-4MHVUSF-QVU2GAX";
    };
  };

  otherClient = if cfg.deviceName == "portatil" then "sobremesa" else "portatil";
in
{
  options.my.syncthing.deviceName = lib.mkOption {
    type = lib.types.enum [ "portatil" "sobremesa" ];
    description = "Nombre de este dispositivo en la topologia de Syncthing";
  };

  config = {
    sops.secrets.syncthing_encpass = {
      sopsFile = ./secrets.yaml;
      owner = "ruben";
    };

    services.syncthing = {
      enable = true;
      user = "ruben";
      dataDir = "/home/ruben";
      configDir = "/home/ruben/.config/syncthing";
      openDefaultPorts = true;

      # Syncthing's web UI is no longer the source of truth for devices or folders.
      overrideDevices = true;
      overrideFolders = true;

      settings = {
        devices = lib.removeAttrs devices [ cfg.deviceName ];

        folders.Documents = {
          # Keep the existing folder ID so this remains the same shared folder.
          id = "iqzcu-eurtm";
          label = "documents";
          path = "/home/ruben/Documents";
          devices = [
            otherClient
            {
              name = "homeserver";
              encryptionPasswordFile = config.sops.secrets.syncthing_encpass.path;
            }
          ];
        };
      };
    };
  };
}
