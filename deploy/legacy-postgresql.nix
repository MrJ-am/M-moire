# Compatibilité de l'ancienne configuration monoprojet seulement.
# L'infrastructure VPS possède désormais PostgreSQL et les sauvegardes locales.
# Ne pas importer ce fichier dans la nouvelle infrastructure ni l'étendre.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.matheval;
in {
  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_17;
      enableTCPIP = false;
      settings.listen_addresses = lib.mkForce "";
      ensureDatabases = [ "matheval" ];
      ensureUsers = [{ name = "matheval"; ensureDBOwnership = true; }];
    };
    services.postgresqlBackup = {
      enable = true;
      databases = [ "matheval" ];
      startAt = "daily";
      location = "/var/backup/postgresql";
    };
  };
}
