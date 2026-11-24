{ config, ... }:

# Hardware-specific settings that are not part of the generated
# hardware-configuration.nix (disks/filesystems). The machine is a Ryzen
# 9800X3D + Radeon RX 9070 XT (RDNA4) on a Gigabyte B850M GAMING X WIFI6E.
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sr_mod"
  ];

  # amdgpu is needed early for a clean console and for LUKS passphrase display
  # on a GPU-connected display.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # kvm-amd for the disposable test VM; it87 drives the IT8696 Super I/O
  # (fans/pwm) that CoolerControl uses.
  boot.kernelModules = [
    "kvm-amd"
    "it87"
  ];

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # RX 9070 XT + Radeon 610M iGPU. 32-bit graphics is needed by some Wine
  # prefixes and creative tools; OpenCL via ROCm is what Resolve sees.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  hardware.amdgpu.opencl.enable = true;

  # OpenRGB talks to the Gigabyte SMBus/RGB controllers and the DIMMs.
  hardware.i2c.enable = true;

  # RTL8852CE Wi-Fi + Bluetooth and RTL8125 Ethernet are covered by the
  # in-kernel rtw89/r8169 drivers and linux-firmware.

  # Gigabyte's IT8696 sits in an ACPI-claimed region; the it87 driver needs
  # the relaxed resource check or it fails with "No such device".
  boot.kernelParams = [ "acpi_enforce_resources=lax" ];

  # In-tree it87 doesn't recognise the IT8696E; use the out-of-tree driver.
  boot.extraModulePackages = [ config.boot.kernelPackages.it87 ];
}
