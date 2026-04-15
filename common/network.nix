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

    sops.secrets.ovpn_lab_user = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.ovpn_lab_password = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.ovpn_lab_remote_ip = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.ovpn_lab_remote_port = {
      sopsFile = ./secrets.yaml;
    };

    sops.secrets.eduroam_username = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.eduroam_password = {
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

    sops.templates."vpn-lab.nmconnection" = {
      path = "/etc/NetworkManager/system-connections/vpn-lab.nmconnection";
      owner = "root";
      group = "root";
      mode = "0600";
      content = ''
        [connection]
        id=vpn-lab
        type=vpn
        autoconnect=false

        [vpn]
        service-type=org.freedesktop.NetworkManager.openvpn
        remote=${config.sops.placeholder.ovpn_lab_remote_ip}:${config.sops.placeholder.ovpn_lab_remote_port}
	remote-cert-tls=server
        connection-type=password
        tls-cipher=TLS-ECDHE-RSA-WITH-AES-256-GCM-SHA384:TLS-ECDHE-ECDSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-GCM-SHA384:TLS-DHE-RSA-WITH-AES-256-CBC-SHA256:TLS-DHE-RSA-WITH-AES-128-CBC-SHA256
        username=${config.sops.placeholder.ovpn_lab_user}
        challenge-response-flags=2
	cipher=AES-256-CBC
	dev=tun
	proto-tcp=yes
	remote-cert-tls=server
	reneg-seconds=0
	password-flags=0
        ca=/etc/openvpn/ca.crt

        [vpn-secrets]
        password=${config.sops.placeholder.ovpn_lab_password}

        [ipv4]
        method=auto

        [ipv6]
        addr-gen-mode=default
	method=auto
      '';
    };

    sops.templates."eduroam.nmconnection" = {
      path = "/etc/NetworkManager/system-connections/eduroam.nmconnection";
      owner = "root";
      group = "root";
      mode = "0600";
      
      content = ''
        [connection]
        id=eduroam
        type=wifi
        autoconnect=true

        [wifi]
        ssid=eduroam
        security=802-11-wireless-security

        [wifi-security]
        key-mgmt=wpa-eap

        [802-1x]
        eap=ttls;
        identity=${config.sops.placeholder.eduroam_username}
        anonymous-identity=anonymous112025@uc3m.es
        altsubject-matches=DNS:radius.uc3m.es;
        phase2-auth=pap
        password=${config.sops.placeholder.eduroam_password}
        password-flags=0
        ca-cert=/etc/ssl/certs/uc3m-ca.pem
      '';
    };
    
    environment.etc."ssl/certs/uc3m-ca.pem" = {
      mode = "0444";
      text = ''
        -----BEGIN CERTIFICATE-----
        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
        63ZTGI0RmLo=
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        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
        3RfjV9IaUQGJ
        -----END CERTIFICATE-----
        -----BEGIN CERTIFICATE-----
        MIIKCTCCBfGgAwIBAgIUbzH8mjS6ZQiQQxlRXV1glyeVbeYwDQYJKoZIhvcNAQEL
        BQAwgZIxCzAJBgNVBAYTAkVTMQ8wDQYDVQQIDAZNYWRyaWQxEDAOBgNVBAcMB0xl
        Z2FuZXMxKTAnBgNVBAoMIFVuaXZlcnNpZGFkIENhcmxvcyBJSUkgZGUgTWFkcmlk
        MRgwFgYDVQQDDA9jYS11YzNtLnVjM20uZXMxGzAZBgkqhkiG9w0BCQEWDGNlcnRA
        dWMzbS5lczAgFw0yMDExMDQxMTQwMTJaGA8yMDUwMTEyNzExNDAxMlowgZIxCzAJ
        BgNVBAYTAkVTMQ8wDQYDVQQIDAZNYWRyaWQxEDAOBgNVBAcMB0xlZ2FuZXMxKTAn
        BgNVBAoMIFVuaXZlcnNpZGFkIENhcmxvcyBJSUkgZGUgTWFkcmlkMRgwFgYDVQQD
        DA9jYS11YzNtLnVjM20uZXMxGzAZBgkqhkiG9w0BCQEWDGNlcnRAdWMzbS5lczCC
        BCIwDQYJKoZIhvcNAQEBBQADggQPADCCBAoCggQBAJ90pd7TOkrReiFR+TiCK3Rd
        CdOHDOmVHdg954J1Mq+RfiWDoiVIRDDwylrWxvqY15Qv8WMWKJIJqtONdEhCC+Vk
        3OMDzaAXkB/Vbz/7TzAt/DnPa/1cwuKRATtnfl/lBr7VvX/iDI1ztJsU9DGZv2IW
        r3tC0nOtVUNHveh+/++iiPujuuQyVLDjfE51ISXwr3PhJFc6E3BBMTJZ28itHffO
        h1sUJ5Rp1a8OTA0uYAoObfpZT7brb0THbzkK32k70JfmUYwf9H30yCfVObdTkP+y
        kxg3tX1BVkR/Gb3rFmMIND6Gqcy42iLETo6j3zj9uSlTXr3gwfqBNSTyPwH8u1ih
        ejXctR25FB7ke4FB9q1gBwOMijdgluMxFFO1Ur2zW4Vn0e/8fYXwtHOLS1rJJ4PL
        jbgd0S8gIY3i8fGp5FnTgXALdKsU5agZ3xELjRJnGYu9G2DyAxyMy/Or7p6GopVk
        aLki5JVvVkEfZMyTnPetxg1qtaiVa8s2Pvc2C/eb9vBxhQwO1dVy4ymahhlLqHrV
        QaedpI/HLqxTMmfyQctmG1tFGoTlFOs9pwl1/vY2H08iJ2XKH9viOCVvbHykcCUg
        l5H4nrVAivIWjYPeBb4yh6UkpUDEGSrPEFBqhGvdmKNtDQSAWOs3mrOFHSpquSa+
        pCYeEz3lWHPrteiUXGBnb1uJl9IJtdMrsoQwpaYn1k8QZvdojPstVXkNRdC+xK4P
        8jJ5E4em0gPuE02ay1PFn8i0mu2NM4KeBIjyJwTpvazGv4a1ez00LA3PnDCIG/2o
        gN7lE6A1in1EAFYiSSEUTZC8kA1R/tXiBLNJobgJRl43gGl3BX91cbt1UZvrQK5e
        +SUs7NDFb8BY3CDHG2t858ZJJ65e5ua2AOFezZt090i6/Hyp4uewbMQdzre5XUEF
        vTViTHrM3YJmLZUTHcsH/lTpuh6x+ZwMrEaeVZwAPHVIjlbb3vmHNfS8fj36Cq3Q
        t5gr6Ta4yaQlHAibMxxv3ofJfkw7xUjiUQR6F7IAw3VywTUERQYsKriZVqAjqPZV
        wZMOPbbZe8P43nmSDHzXoosXIwjYP44o7PtTj0ieAKSZig4WgtHTTZsCJyW1n/LJ
        y/GzUIyzuycIlRkGOnuLqWBAqYs7afKPz1KZSPtx1UEWaeZznQ8DFK6M2eozEi3s
        a3rc++bU/LRkAqd0tmtfZ2KrprZR71k4wksvc8jYzBEvKUYht2q/H3/VUKo2neK8
        PcoTMcguKdTnsEcuIEcSZHZS0ojeiQrtr8BFCB+Doe+sCxIIPDRcYH1JrZTXmJ25
        EKo3AVSUKrAMtatWuSlgaw1sUeN45bFUl+NI3vUWDlF3FfRANnTRecmfyCPGrJkC
        AwEAAaNTMFEwHQYDVR0OBBYEFJfpLmNkR4250xOYvelB+gRaHVeBMB8GA1UdIwQY
        MBaAFJfpLmNkR4250xOYvelB+gRaHVeBMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZI
        hvcNAQELBQADggQBAAkdaJHFpuNauJfCSUVqtBlCpFGejS5T+YJcSTxCKbn6J6ur
        nueaYXnnmBeV9yvfnKyk11hFdxY6esNNZcKO75aOtSfEdaHK4Qw1XulMJxfYZPaf
        gUSg02dXk+NX9y9kaUJ2n+IKtyVFWyqypyE1yM3PwYSAaERh59eIajpdsyV3rLKN
        pGLoSaYTQsoRD0VC8k5S4lpzFYcDzkn8r7nLHEdc0T3HX2Rhnf9cf+GvJX9U3gNk
        Chjg/+FQTmj290C4jcBr3bDu1MVdiRcoy9C/NiP5JXfON7mxW1cgaMF9i9pHC08T
        Xi7vvb7FzxCHYdGzomhzIpjgYgG94gJ1URzYJ0Ywtl7JV4Sm04hLT29vSwxaMmuk
        51MiJwNVtz8oE/1bA2yg8r3jHGSaeA0vcjXmJTPL27qSO2PKrpFGaTRtULnv4w8j
        zKJ2F5//PBu47D2Rg0nGQG0rz2UopACpyhliCccIiUNB7XTO8ob6M43WCwKJVv4G
        o+gRh5IkpEYAJ0Cw+AS6JDOLRRJqV7i8ieYjYSsWxBxMK0kduSg7NS2YvSubbBbU
        4jbpfQpQb98PnVe4pMp+RbMvTeFHz2I/d1na5ZgFelE5RSwvCqG9EaxACYAucuVf
        XZh6PuKAD0ugHRFglmm6r13+Sslq2lI/LZ7WbUzy9o2L7FUx3VdnaNmqxKvPE6Ui
        k6AdPM6Wo9QunUMA2ScITWknnZ9trzfNt43ACGE0kx4ZgB4ABK7Sv70RR9jJU+Z5
        aGbPozV57oBg0jDAqrIztfBtJbh2fkGaWSNXP0XyREVtkO8v993ezwtMdPMYetv0
        Ndhf/GzrQYK3gOo/khQbw54ICMiwE+lOCz4MHYQoY+K/BBH0oIVmMjh1E+aYF3xi
        xEkT+zkR77B7vdHfOWOgWTEZ78PpzpdQVHKR8G9vp1bY3qIYBnhx/OWUFWSA9w37
        C5aLGM9QPCuRk658/d+PlR9gMCaUmNcJrCqZFiNTJuQskt/cp3Bs8VL4dpL+Z3p2
        Ju7EXpY5TpuoKMV6bF0M2tw3MXOtg5WjeyCpYWUB5g9TUeqFqdiwMPjZkojdwK1e
        6iizKFk0UjVTSlKFPNPKAF4UzER9V2FT4m3Zj3pJZFOsV+KFdFXpB/vmYXlgT8jn
        WeMGnWPnS2OS0ITRgPFJf1M5fJ1OHr17Gljfp9rW52EVAZ7sxUrCili5xfP1yhFU
        EGi6FOyXXDgclgfkCtmjg2u00f3FMlVqF39zqFAFV78e9prMUEJ2hVCwiUdaO1Ub
        rwukg/eNBZ9vG2+BfqDcJafMoIKZs9OsAIKH63PvatGq5QJpcdf+cMc/tQBWi1nq
        Ru8hoROl7XPkuFHkm1AAftn2Ri7YyKzYhJrgurs=
        -----END CERTIFICATE-----
      '';
    };
  };
}
