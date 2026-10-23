{ pkgs, ... }:

{
  services.mysql = {
    enable = true;
    package = pkgs.mysql84;

    # Keep the database available to local applications only.
    settings.mysqld.bind-address = "127.0.0.1";
  };
}
