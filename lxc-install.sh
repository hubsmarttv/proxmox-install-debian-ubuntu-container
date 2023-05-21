#!/usr/bin/env bash

variables() {
  NSAPP=$(echo ${APP,,} | tr -d ' ')  # This function sets the NSAPP variable by converting the value of the APP variable to lowercase and removing any spaces.
  var_install="${NSAPP}-install"      # sets the var_install variable by appending "-install" to the value of NSAPP.
  INTEGER='^[0-9]+([.][0-9]+)?$'      # it defines the INTEGER regular expression pattern.
}

# This function sets various color variables using ANSI escape codes for formatting text in the terminal.
color() {
  YW=$(echo "\033[33m")
  BL=$(echo "\033[36m")
  RD=$(echo "\033[01;31m")
  BGN=$(echo "\033[4;92m")
  GN=$(echo "\033[1;92m")
  DGN=$(echo "\033[32m")
  CL=$(echo "\033[m")
  CM="${GN}✓${CL}"
  CROSS="${RD}✗${CL}"
  BFR="\\r\\033[K"
  HOLD="-"
}

# This function enables error handling in the script by setting options and defining a trap for the ERR signal.
catch_errors() {
  set -Eeuo pipefail
  trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
}

# This function is called when an error occurs. It receives the exit code, line number, and command that caused the error, and displays an error message.
error_handler() {
  local exit_code="$?"
  local line_number="$1"
  local command="$2"
  local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
  echo -e "\n$error_message\n"
}

# This function displays an informational message with a yellow color.
msg_info() {
  local msg="$1"
  echo -ne " ${HOLD} ${YW}${msg}..."
}

# This function displays a success message with a green color.
msg_ok() {
  local msg="$1"
  echo -e "${BFR} ${CM} ${GN}${msg}${CL}"
}

# This function displays an error message with a red color.
msg_error() {
  local msg="$1"
  echo -e "${BFR} ${CROSS} ${RD}${msg}${CL}"
}

# This function checks the version of Proxmox Virtual Environment (PVE) and exits if the version is not supported.
pve_check() {
  if [ $(pveversion | grep -c "pve-manager/7\.[0-9]") -eq 0 ]; then
    echo -e "${CROSS} This version of Proxmox Virtual Environment is not supported"
    echo -e "Requires PVE Version 7.0 or higher"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

# This function checks the system architecture and exits if it's not "amd64".
arch_check() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo -e "\n ${CROSS} This script will not work with PiMox! \n"
    echo -e "Exiting..."
    sleep 2
    exit
  fi
}

# This function checks if the script is running through SSH and prompts the user to confirm if they want to proceed or exit.
ssh_check() {
  if command -v pveversion >/dev/null 2>&1; then
    if [ -n "${SSH_CLIENT:+x}" ]; then
      if whiptail --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
        echo "you've been warned"
      else
        clear
        exit
      fi
    fi
  fi
}

# This function displays the default values for various settings.
echo_default() {
  echo -e "${DGN}Using Distribution: ${BGN}$var_os${CL}"
  echo -e "${DGN}Using $var_os Version: ${BGN}$var_version${CL}"
  echo -e "${DGN}Using Container Type: ${BGN}$CT_TYPE${CL}"
  echo -e "${DGN}Using Root Password: ${BGN}Automatic Login${CL}"
  echo -e "${DGN}Using Container ID: ${BGN}$NEXTID${CL}"
  echo -e "${DGN}Using Hostname: ${BGN}$NSAPP${CL}"
  echo -e "${DGN}Using Disk Size: ${BGN}$var_disk${CL}${DGN}GB${CL}"
  echo -e "${DGN}Allocated Cores ${BGN}$var_cpu${CL}"
  echo -e "${DGN}Allocated Ram ${BGN}$var_ram${CL}"
  echo -e "${DGN}Using Bridge: ${BGN}vmbr0${CL}"
  echo -e "${DGN}Using Static IP Address: ${BGN}dhcp${CL}"
  echo -e "${DGN}Using Gateway Address: ${BGN}Default${CL}"
  echo -e "${DGN}Disable IPv6: ${BGN}No${CL}"
  echo -e "${DGN}Using Interface MTU Size: ${BGN}Default${CL}"
  echo -e "${DGN}Using DNS Search Domain: ${BGN}Host${CL}"
  echo -e "${DGN}Using DNS Server Address: ${BGN}Host${CL}"
  echo -e "${DGN}Using MAC Address: ${BGN}Default${CL}"
  echo -e "${DGN}Using VLAN Tag: ${BGN}Default${CL}"
  echo -e "${DGN}Enable Root SSH Access: ${BGN}No${CL}"
  if [[ "$APP" == "Docker" || "$APP" == "Umbrel" || "$APP" == "CasaOS" || "$APP" == "Home Assistant" ]]; then
    echo -e "${DGN}Enable Fuse Overlayfs (ZFS): ${BGN}No${CL}"
  fi
  echo -e "${DGN}Enable Verbose Mode: ${BGN}No${CL}"
  echo -e "${BL}Creating a ${APP} LXC using the above default settings${CL}"
}

# This function is called when the user decides to exit the script. It clears the screen and displays an exit message.
exit-script() {
  clear
  echo -e "⚠  User exited script \n"
  exit
}

# This function allows the user to configure advanced settings for the script.
advanced_settings() {
  whiptail --msgbox --title "Here is an instructional tip:" "To make a selection, use the Spacebar." 8 58
  whiptail --msgbox --title "Default distribution for $APP" "${var_os} \n${var_version} \n" 8 58
  if [ "$var_os" != "alpine" ]; then
    var_os=""
    while [ -z "$var_os" ]; do
      if var_os=$(whiptail --title "DISTRIBUTION" --radiolist "Choose Distribution:" 10 58 2 \
        "debian" "" OFF \
        "ubuntu" "" OFF \
        3>&1 1>&2 2>&3); then
        if [ -n "$var_os" ]; then
          echo -e "${DGN}Using Distribution: ${BGN}$var_os${CL}"
        fi
      else
        exit-script
      fi
    done
  fi

  if [ "$var_os" == "debian" ]; then
    var_version="11"
    echo -e "${DGN}Using $var_os Version: ${BGN}$var_version${CL}"
  fi

  if [ "$var_os" == "ubuntu" ]; then
    var_version=""
    while [ -z "$var_version" ]; do
      if var_version=$(whiptail --title "UBUNTU VERSION" --radiolist "Choose Version" 10 58 3 \
        "20.04" "Focal" OFF \
        "22.04" "Jammy" OFF \
        "22.10" "Kinetic" OFF \
        3>&1 1>&2 2>&3); then
        if [ -n "$var_version" ]; then
          echo -e "${DGN}Using $var_os Version: ${BGN}$var_version${CL}"
        fi
      else
        exit-script
      fi
    done
  fi

  CT_TYPE=""
  while [ -z "$CT_TYPE" ]; do
    if CT_TYPE=$(whiptail --title "CONTAINER TYPE" --radiolist "Choose Type" 10 58 2 \
      "1" "Unprivileged" OFF \
      "0" "Privileged" OFF \
      3>&1 1>&2 2>&3); then
      if [ -n "$CT_TYPE" ]; then
        echo -e "${DGN}Using Container Type: ${BGN}$CT_TYPE${CL}"
      fi
    else
      exit-script
    fi
  done

  if PW1=$(whiptail --inputbox "\nSet Root Password (needed for root ssh access)" 9 58 --title "PASSWORD(leave blank for automatic login)" 3>&1 1>&2 2>&3); then
    if [ -z $PW1 ]; then
      PW1="Automatic Login"
      PW=""
    else
      PW="-password $PW1"
    fi
    echo -e "${DGN}Using Root Password: ${BGN}$PW1${CL}"
  else
    exit-script
  fi

  if CT_ID=$(whiptail --inputbox "Set Container ID" 8 58 $NEXTID --title "CONTAINER ID" 3>&1 1>&2 2>&3); then
    if [ -z "$CT_ID" ]; then
      CT_ID="$NEXTID"
      echo -e "${DGN}Using Container ID: ${BGN}$CT_ID${CL}"
    else
      echo -e "${DGN}Container ID: ${BGN}$CT_ID${CL}"
    fi
  else
    exit
  fi

  if CT_NAME=$(whiptail --inputbox "Set Hostname" 8 58 $NSAPP --title "HOSTNAME" 3>&1 1>&2 2>&3); then
    if [ -z "$CT_NAME" ]; then
      HN="$NSAPP"
    else
      HN=$(echo ${CT_NAME,,} | tr -d ' ')
    fi
    echo -e "${DGN}Using Hostname: ${BGN}$HN${CL}"
  else
    exit-script
  fi

  if DISK_SIZE=$(whiptail --inputbox "Set Disk Size in GB" 8 58 $var_disk --title "DISK SIZE" 3>&1 1>&2 2>&3); then
    if [ -z "$DISK_SIZE" ]; then
      DISK_SIZE="$var_disk"
      echo -e "${DGN}Using Disk Size: ${BGN}$DISK_SIZE${CL}"
    else
      if ! [[ $DISK_SIZE =~ $INTEGER ]]; then
        echo -e "${RD}⚠ DISK SIZE MUST BE AN INTEGER NUMBER!${CL}"
        advanced_settings
      fi
      echo -e "${DGN}Using Disk Size: ${BGN}$DISK_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if CORE_COUNT=$(whiptail --inputbox "Allocate CPU Cores" 8 58 $var_cpu --title "CORE COUNT" 3>&1 1>&2 2>&3); then
    if [ -z "$CORE_COUNT" ]; then
      CORE_COUNT="$var_cpu"
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    else
      echo -e "${DGN}Allocated Cores: ${BGN}$CORE_COUNT${CL}"
    fi
  else
    exit-script
  fi

  if RAM_SIZE=$(whiptail --inputbox "Allocate RAM in MiB" 8 58 $var_ram --title "RAM" 3>&1 1>&2 2>&3); then
    if [ -z "$RAM_SIZE" ]; then
      RAM_SIZE="$var_ram"
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    else
      echo -e "${DGN}Allocated RAM: ${BGN}$RAM_SIZE${CL}"
    fi
  else
    exit-script
  fi

  if BRG=$(whiptail --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" 3>&1 1>&2 2>&3); then
    if [ -z "$BRG" ]; then
      BRG="vmbr0"
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    else
      echo -e "${DGN}Using Bridge: ${BGN}$BRG${CL}"
    fi
  else
    exit-script
  fi

  while true; do
    NET=$(whiptail --inputbox "Set a Static IPv4 CIDR Address (/24)" 8 58 dhcp --title "IP ADDRESS" 3>&1 1>&2 2>&3)
    exit_status=$?
    if [ $exit_status -eq 0 ]; then
      if [ "$NET" = "dhcp" ]; then
        echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}"
        break
      else
        if [[ "$NET" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
          echo -e "${DGN}Using IP Address: ${BGN}$NET${CL}"
          break
        else
          whiptail --msgbox "$NET is an invalid IPv4 CIDR address. Please enter a valid IPv4 CIDR address or 'dhcp'" 8 58
        fi
      fi
    else
      exit-script
    fi
  done

  if [ "$NET" != "dhcp" ]; then
    while true; do
      GATE1=$(whiptail --inputbox "Enter gateway IP address" 8 58 --title "Gateway IP" 3>&1 1>&2 2>&3)
      if [ -z "$GATE1" ]; then
        whiptail --msgbox "Gateway IP address cannot be empty" 8 58
      elif [[ ! "$GATE1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        whiptail --msgbox "Invalid IP address format" 8 58
      else
        GATE=",gw=$GATE1"
        echo -e "${DGN}Using Gateway IP Address: ${BGN}$GATE1${CL}"
        break
      fi
    done
  else
    GATE=""
    echo -e "${DGN}Using Gateway IP Address: ${BGN}Default${CL}"
  fi

  if (whiptail --defaultno --title "IPv6" --yesno "Disable IPv6?" 10 58); then
    DISABLEIP6="yes"
  else
    DISABLEIP6="no"
  fi
  echo -e "${DGN}Disable IPv6: ${BGN}$DISABLEIP6${CL}"

  if MTU1=$(whiptail --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" 3>&1 1>&2 2>&3); then
    if [ -z $MTU1 ]; then
      MTU1="Default"
      MTU=""
    else
      MTU=",mtu=$MTU1"
    fi
    echo -e "${DGN}Using Interface MTU Size: ${BGN}$MTU1${CL}"
  else
    exit-script
  fi

  if SD=$(whiptail --inputbox "Set a DNS Search Domain (leave blank for HOST)" 8 58 --title "DNS Search Domain" 3>&1 1>&2 2>&3); then
    if [ -z $SD ]; then
      SX=Host
      SD=""
    else
      SX=$SD
      SD="-searchdomain=$SD"
    fi
    echo -e "${DGN}Using DNS Search Domain: ${BGN}$SX${CL}"
  else
    exit-script
  fi

  if NX=$(whiptail --inputbox "Set a DNS Server IP (leave blank for HOST)" 8 58 --title "DNS SERVER IP" 3>&1 1>&2 2>&3); then
    if [ -z $NX ]; then
      NX=Host
      NS=""
    else
      NS="-nameserver=$NX"
    fi
    echo -e "${DGN}Using DNS Server IP Address: ${BGN}$NX${CL}"
  else
    exit-script
  fi

  if MAC1=$(whiptail --inputbox "Set a MAC Address(leave blank for default)" 8 58 --title "MAC ADDRESS" 3>&1 1>&2 2>&3); then
    if [ -z $MAC1 ]; then
      MAC1="Default"
      MAC=""
    else
      MAC=",hwaddr=$MAC1"
      echo -e "${DGN}Using MAC Address: ${BGN}$MAC1${CL}"
    fi
  else
    exit-script
  fi

  if VLAN1=$(whiptail --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" 3>&1 1>&2 2>&3); then
    if [ -z $VLAN1 ]; then
      VLAN1="Default"
      VLAN=""
    else
      VLAN=",tag=$VLAN1"
    fi
    echo -e "${DGN}Using Vlan: ${BGN}$VLAN1${CL}"
  else
    exit-script
  fi

  if [[ "$PW" == -password* ]]; then
    if (whiptail --defaultno --title "SSH ACCESS" --yesno "Enable Root SSH Access?" 10 58); then
      SSH="yes"
    else
      SSH="no"
    fi
    echo -e "${DGN}Enable Root SSH Access: ${BGN}$SSH${CL}"
  else
    SSH="no"
    echo -e "${DGN}Enable Root SSH Access: ${BGN}$SSH${CL}"
  fi

  if [[ "$APP" == "Docker" || "$APP" == "Umbrel" || "$APP" == "CasaOS" || "$APP" == "Home Assistant" ]]; then
    if (whiptail --defaultno --title "FUSE OVERLAYFS" --yesno "(ZFS) Enable Fuse Overlayfs?" 10 58); then
      FUSE="yes"
    else
      FUSE="no"
    fi
    echo -e "${DGN}Enable Fuse Overlayfs (ZFS): ${BGN}$FUSE${CL}"
  fi

  if (whiptail --defaultno --title "VERBOSE MODE" --yesno "Enable Verbose Mode?" 10 58); then
    VERB="yes"
  else
    VERB="no"
  fi
  echo -e "${DGN}Enable Verbose Mode: ${BGN}$VERB${CL}"

  if (whiptail --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create ${APP} LXC?" 10 58); then
    echo -e "${RD}Creating a ${APP} LXC using the above advanced settings${CL}"
  else
    clear
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

install_script() {
  ssh_check
  arch_check
  pve_check
  if systemctl is-active -q ping-instances.service; then
    systemctl stop ping-instances.service
  fi
  NEXTID=$(pvesh get /cluster/nextid)
  timezone=$(cat /etc/timezone)
  header_info
  if (whiptail --title "SETTINGS" --yesno "Use Default Settings?" --no-button Advanced 10 58); then
    header_info
    echo -e "${BL}Using Default Settings${CL}"
    default_settings
  else
    header_info
    echo -e "${RD}Using Advanced Settings${CL}"
    advanced_settings
  fi
}

start() {
  if command -v pveversion >/dev/null 2>&1; then
    if ! (whiptail --title "${APP} LXC" --yesno "This will create a New Debian or Ubuntu  LXC.  Proceed?" 10 58); then
      clear
      echo -e "⚠  User exited script \n"
      exit
    fi
    install_script
  fi

  if ! command -v pveversion >/dev/null 2>&1; then
    if ! (whiptail --title "${APP} LXC UPDATE" --yesno "This will update ${APP} LXC.  Proceed?" 10 58); then
      clear
      echo -e "⚠  User exited script \n"
      exit
    fi
    update_script
  fi
}

# This function collects user settings and integrates all the collected information.
build_container() {
  if [ "$VERB" == "yes" ]; then set -x; fi

  if [[ "$APP" == "Docker" || "$APP" == "Umbrel" || "$APP" == "CasaOS" || "$APP" == "Home Assistant" ]]; then
    if [ "$FUSE" == "yes" ]; then
      FEATURES="fuse=1,keyctl=1,nesting=1"
    else
      FEATURES="keyctl=1,nesting=1"
    fi
  fi
  if [[ "$APP" != "Docker" && "$APP" != "Umbrel" && "$APP" != "CasaOS" && "$APP" != "Home Assistant" ]]; then
    if [ "$CT_TYPE" == "1" ]; then
      FEATURES="keyctl=1,nesting=1"
    else
      FEATURES="nesting=1"
    fi
  fi

  TEMP_DIR=$(mktemp -d)
  pushd $TEMP_DIR >/dev/null
  if [ "$var_os" == "alpine" ]; then
    export FUNCTIONS_FILE_PATH="$(curl -s https://raw.githubusercontent.com/tteck/Proxmox/main/misc/alpine-install.func)"
  else
    export FUNCTIONS_FILE_PATH="$(curl -s https://raw.githubusercontent.com/tteck/Proxmox/main/misc/install.func)"
  fi
  export tz="$timezone"
  if [[ "$APP" == "Docker" || "$APP" == "Umbrel" || "$APP" == "CasaOS" || "$APP" == "Home Assistant" ]]; then
    export ST="$FUSE"
  fi
  export DISABLEIPV6="$DISABLEIP6"
  export APPLICATION="$APP"
  export PASSWORD="$PW"
  export VERBOSE="$VERB"
  export SSH_ROOT="${SSH}"
  export CTID="$CT_ID"
  export CTTYPE="$CT_TYPE"
  export PCT_OSTYPE="$var_os"
  export PCT_OSVERSION="$var_version"
  export PCT_DISK_SIZE="$DISK_SIZE"
  export PCT_OPTIONS="
    -features $FEATURES
    -hostname $HN
    -tags proxmox-helper-scripts
    $SD
    $NS
    -net0 name=eth0,bridge=$BRG$MAC,ip=$NET$GATE$VLAN$MTU
    -onboot 1
    -cores $CORE_COUNT
    -memory $RAM_SIZE
    -unprivileged $CT_TYPE
    $PW
  "
  # This executes create_lxc.sh and creates the container and .conf file
  bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/ct/create_lxc.sh)" || exit

  LXC_CONFIG=/etc/pve/lxc/${CTID}.conf
  if [ "$CT_TYPE" == "0" ]; then
    if [[ "$APP" != "Emby" && "$APP" != "Jellyfin" && "$APP" != "Plex" && "$APP" != "Tdarr" ]]; then
      cat <<EOF >>$LXC_CONFIG
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 188:* rwm
lxc.cgroup2.devices.allow: c 189:* rwm
lxc.mount.entry: /dev/serial/by-id  dev/serial/by-id  none bind,optional,create=dir
lxc.mount.entry: /dev/ttyUSB0       dev/ttyUSB0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyUSB1       dev/ttyUSB1       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM0       dev/ttyACM0       none bind,optional,create=file
lxc.mount.entry: /dev/ttyACM1       dev/ttyACM1       none bind,optional,create=file
EOF
    fi
  fi

  if [ "$CT_TYPE" == "0" ]; then
    if [[ "$APP" == "Emby" || "$APP" == "Jellyfin" || "$APP" == "Plex" || "$APP" == "Tdarr" ]]; then
      cat <<EOF >>$LXC_CONFIG
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
lxc.cgroup2.devices.allow: c 226:0 rwm
lxc.cgroup2.devices.allow: c 226:128 rwm
lxc.cgroup2.devices.allow: c 29:0 rwm
lxc.mount.entry: /dev/fb0 dev/fb0 none bind,optional,create=file
lxc.mount.entry: /dev/dri dev/dri none bind,optional,create=dir
lxc.mount.entry: /dev/dri/renderD128 dev/dri/renderD128 none bind,optional,create=file
EOF
    fi
  fi

# This starts the container and executes <app>-install.sh
  msg_info "Starting LXC Container"
  pct start "$CTID"
  msg_ok "Started LXC Container"
  if [ "$var_os" == "alpine" ]; then
    sleep 2
    pct exec "$CTID" -- ash -c "apk add bash >/dev/null"
  fi
  lxc-attach -n "$CTID" -- bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/install/$var_install.sh)" || exit

}

# This function sets the description of the container.
description() {
  IP=$(pct exec "$CTID" ip a s dev eth0 | awk '/inet / {print $2}' | cut -d/ -f1)
  pct set "$CTID" -description "# ${APP} LXC
  ### https://github.com/hubsmarttv
  <a href='https://ko-fi.com/D1D7EP4GF'><img src='https://img.shields.io/badge/☕-Buy me a coffee-red' /></a>"
  if [[ -f /etc/systemd/system/ping-instances.service ]]; then
    systemctl start ping-instances.service
  fi
}



# 
# 
# 
# 

function header_info {
clear
cat <<"EOF"
   __  ____                __       
  / / / / /_  __  ______  / /___  __
 / / / / __ \/ / / / __ \/ __/ / / /
/ /_/ / /_/ / /_/ / / / / /_/ /_/ / 
\____/_.___/\__,_/_/ /_/\__/\__,_/  
 
EOF
}
header_info
echo -e "Loading..."
APP="Ubuntu"
var_disk="2"
var_cpu="2"
var_ram="4096"
var_os="ubuntu"
var_version="22.04"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="0"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  DISABLEIP6="yes"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
header_info
if [[ ! -d /var ]]; then msg_error "No ${APP} Installation Found!"; exit; fi
msg_info "Updating ${APP} LXC"
apt-get update &>/dev/null
apt-get -y upgrade &>/dev/null
msg_ok "Updated ${APP} LXC"
exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
