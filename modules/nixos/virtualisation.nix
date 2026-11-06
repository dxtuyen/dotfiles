{ lib, userName, ... }:

{
  # Manage QEMU/KVM virtual machines with the virt-manager GUI.
  virtualisation.libvirtd = {
    enable = true;
    onBoot = "ignore";
  };
  programs.virt-manager.enable = true;

  # Start libvirt manually; keep guest shutdown handling when it is used.
  systemd.services.libvirtd = {
    wantedBy = lib.mkForce [ ];
    wants = [ "libvirt-guests.service" ];
  };
  systemd.services.libvirt-guests.wantedBy = lib.mkForce [ ];

  # Otherwise a client connection could start libvirt without an explicit start.
  # libvirtd.service pulls these sockets in when started manually.
  systemd.sockets =
    lib.genAttrs
      [
        "libvirtd"
        "libvirtd-ro"
        "libvirtd-admin"
        "virtlogd"
        "virtlockd"
      ]
      (_: {
        wantedBy = lib.mkForce [ ];
      });

  users.users.${userName}.extraGroups = [
    "kvm"
    "libvirtd"
  ];
}
