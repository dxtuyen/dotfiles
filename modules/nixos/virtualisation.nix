{ userName, ... }:

{
  # Manage QEMU/KVM virtual machines with the virt-manager GUI.
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  users.users.${userName}.extraGroups = [
    "kvm"
    "libvirtd"
  ];
}
