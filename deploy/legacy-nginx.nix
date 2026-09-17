# Compatibilité de l'ancienne configuration monoprojet seulement.
# L'infrastructure VPS possède désormais la configuration de la passerelle.
# Ne pas importer ce fichier dans la nouvelle infrastructure ni l'étendre.
{ config, lib, ... }:
let
  cfg = config.services.matheval;
in {
  config = lib.mkIf cfg.enable {
    security.acme.acceptTerms = true;
    services.nginx.enable = true;
    services.nginx.virtualHosts."${cfg.domain}" = {
      enableACME = true;
      forceSSL = true;
      locations."= /".return = "308 /matheval/";
      locations."= /matheval".return = "308 /matheval/";
      locations."/matheval/" = {
        proxyPass = "http://127.0.0.1:3000";
        extraConfig = ''
          client_max_body_size 5m;
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_set_header X-Forwarded-For $remote_addr;
        '';
      };
    };
    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
