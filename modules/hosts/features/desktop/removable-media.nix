# Removable storage (USB sticks, and SD cards behind a USB reader/hub). udisks2
# provides the DBus mount service and pulls in polkit; the supported
# filesystems install the kernel modules and fsck tools udisks2 needs to mount
# the common removable formats read-write.
{
  services.udisks2.enable = true;
  boot.supportedFilesystems = [
    "vfat"
    "exfat"
    "ntfs"
  ];
}
