{ lib, pkgs, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.mysql84;

    # Keep the database available to local applications only.
    settings.mysqld.bind-address = "127.0.0.1";
  };

  # Keep MySQL configured, but start it only with systemctl start mysql.
  systemd.services.mysql.wantedBy = lib.mkForce [ ];
}
