#!/bin/sh
#
# FreeBSD Installation Script for Archived Versions (pre-8.x)
# using distribution files in the current directory.
#

# Default configuration file path
CONFIG_FILE="./freebsdstrap-archive-sh.conf"

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--config)
      if [ -n "$2" ]; then
        CONFIG_FILE="$2"
        shift 2
      else
        echo "ERROR: --config requires a file path argument"
        exit 1
      fi
      ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "Options:"
      echo "  -c, --config PATH    Specify configuration file (default: ./freebsdstrap-archive-sh.conf)"
      echo "  -h, --help           Display this help message"
      echo "Example: $0 --config /path/to/my/config.conf"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help to see available options"
      exit 1
      ;;
  esac
done

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
  echo "Loading configuration from: $CONFIG_FILE"
  # shellcheck source=/dev/null
  . "$CONFIG_FILE"
else
  echo "ERROR: Configuration file $CONFIG_FILE not found"
  exit 1
fi

check_required_vars() {
  for var in DISK IFACE CHROOT_DIR SWAP_SIZE BASE_ARCHIVE KERNEL_ARCHIVE; do
    if [ -z "$(eval echo \$var)" ]; then
      echo "ERROR: Required variable $var is not set"
      exit 1
    fi
  done

  # Check if distribution files exist
  if [ ! -f "$BASE_ARCHIVE" ]; then
    echo "ERROR: Base archive file $BASE_ARCHIVE not found in current directory"
    exit 1
  fi

  if [ ! -f "$KERNEL_ARCHIVE" ]; then
    echo "ERROR: Kernel archive file $KERNEL_ARCHIVE not found in current directory"
    exit 1
  fi
}

prepare_disk() {
  echo "===> Starting disk partitioning: $DISK"
  gpart destroy -F "$DISK"
  gpart create -s gpt "$DISK"

  # Create a small boot partition first
  gpart add -s 64K -t freebsd-boot -l boot "$DISK"

  # Add swap partition after boot partition
  gpart add -s "$SWAP_SIZE" -t freebsd-swap -l swap0 "$DISK"

  # Add root partition last to allow for future expansion
  gpart add -t freebsd-ufs -l rootfs "$DISK"

  # Install bootcode
  gpart bootcode -b /boot/pmbr -p /boot/gptboot -i 1 "$DISK"

  echo "===> Creating UFS filesystem"
  newfs -U /dev/"${DISK}"p3

  echo "===> Creating mount point: $CHROOT_DIR"
  mkdir -p "$CHROOT_DIR"
  mount /dev/"${DISK}"p3 "$CHROOT_DIR"
}

extract_base_files() {
  echo "===> Extracting base archive to: $CHROOT_DIR"
  echo "    Extracting: $BASE_ARCHIVE"
  if ! tar -xpf "$BASE_ARCHIVE" -C "$CHROOT_DIR"; then
    echo "ERROR: Failed to extract $BASE_ARCHIVE"
    return 1
  fi
}

extract_kernel_files() {
  echo "===> Extracting kernel archive to: $CHROOT_DIR/boot/kernel"
  echo "    Extracting: $KERNEL_ARCHIVE"

  if ! tar -xpf "$KERNEL_ARCHIVE" --strip-components=1 -C "$CHROOT_DIR/boot/kernel"; then
    echo "ERROR: Failed to extract $KERNEL_ARCHIVE"
    return 1
  fi

  return 0
}

# Function to configure the installed system
configure_system() {
  echo "===> Creating system configuration files"
  # rc.conf
  cat > "${CHROOT_DIR}/etc/rc.conf" <<EOF
hostname="${HOST_NAME:-freebsd.local}"
keymap="us.iso.kbd"
ifconfig_${IFACE}="inet ${IP_ADDRESS} netmask ${NETMASK}"
defaultrouter="${GATEWAY}"
sshd_enable="${ENABLE_SSH}"
dumpdev="AUTO"
EOF

  # resolv.conf
  cat > "${CHROOT_DIR}/etc/resolv.conf" <<EOF
nameserver ${DNS_SERVER}
EOF

  # fstab
  cat > "${CHROOT_DIR}/etc/fstab" <<EOF
# Device        Mountpoint      FStype  Options Dump    Pass#
/dev/${DISK}p3     /               ufs     rw      1       1
/dev/${DISK}p2     none            swap    sw      0       0
EOF

  echo "===> Creating system setup script"
  cat > "${CHROOT_DIR}/tmp/freebsd_setup.sh" <<EOF
newaliases
touch /etc/wall_cmos_clock
tzsetup ${TIMEZONE}

dumpon /dev/${DISK}p2
ln -sf /dev/${DISK}p2 /dev/dumpdev
EOF

  echo "===> Creating user account setup script"
  cat > "${CHROOT_DIR}/tmp/user_account.sh" <<EOF
printf "${ROOT_PASSWORD_HASH}" | pw usermod -n root -H 0

pw useradd -n ${DEFAULT_USER} -s ${DEFAULT_USER_SHELL} -G ${DEFAULT_USER_GROUPS} -m
printf "${DEFAULT_USER_PASSWORD_HASH}" | pw usermod -n ${DEFAULT_USER} -H 0
EOF

  echo "===> Applying system settings in chroot"
  mount -t devfs dev "${CHROOT_DIR}/dev"
  chroot "$CHROOT_DIR" /bin/sh /tmp/freebsd_setup.sh
  chroot "$CHROOT_DIR" /bin/sh /tmp/user_account.sh

  echo "===> Removing temporary files"
  rm "${CHROOT_DIR}/tmp/freebsd_setup.sh"
  rm "${CHROOT_DIR}/tmp/user_account.sh"
}

install_system() {
  prepare_disk

  extract_base_files
  extract_kernel_files

  configure_system

  echo "===> Installation completed successfully"
}

main() {
  check_required_vars
  install_system
}

main "$@"
