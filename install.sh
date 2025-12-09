#!/bin/bash

set -e

######################################################################################
#                                                                                    #
# Project 'KS HOSTING BY KSGAMING'                                                   #
#                                                                                    #
# Copyright (C) 2018 - 2025, KS HOSTING BY KSGAMING                                  #
#                                                                                    #
#   This program is free software: you can redistribute it and/or modify             #
#   it under the terms of the GNU General Public License as published by             #
#   the Free Software Foundation, either version 3 of the License, or                #
#   (at your option) any later version.                                              #
#                                                                                    #
#   This program is distributed in the hope that it will be useful,                  #
#   but WITHOUT ANY WARRANTY; without even the implied warranty of                   #
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the                    #
#   GNU General Public License for more details.                                     #
#                                                                                    #
#   You should have received a copy of the GNU General Public License                #
#   along with this program.  If not, see <https://www.gnu.org/licenses/>.           #
#                                                                                    #
# https://github.com/pterodactyl-installer/pterodactyl-installer/blob/master/LICENSE #
#                                                                                    #
# This script is not associated with the official Pterodactyl Project.               #
# https://github.com/pterodactyl-installer/pterodactyl-installer                     #
#                                                                                    #
######################################################################################

export GITHUB_SOURCE="v1.2.0"
export SCRIPT_RELEASE="v1.2.0"
export GITHUB_BASE_URL="https://raw.githubusercontent.com/pterodactyl-installer/pterodactyl-installer"

LOG_PATH="/var/log/pterodactyl-installer.log"

# check for curl
if ! [ -x "$(command -v curl)" ]; then
  echo "* curl is required in order for this script to work."
  echo "* install using apt (Debian and derivatives) or yum/dnf (CentOS)"
  exit 1
fi

# Always remove lib.sh, before downloading it
if [ -f "$(dirname "$0")/lib/lib.sh" ]; then
  source "$(dirname "$0")/lib/lib.sh"
else
  [ -f /tmp/lib.sh ] && rm -rf /tmp/lib.sh
  curl -sSL -o /tmp/lib.sh "$GITHUB_BASE_URL"/master/lib/lib.sh
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh
fi

execute() {
  echo -e "\n\n* ${APP_NAME} Installer $(date) \n\n" >>$LOG_PATH

  [[ "$1" == *"canary"* ]] && export GITHUB_SOURCE="master" && export SCRIPT_RELEASE="canary"
  update_lib_source
  run_ui "${1//_canary/}" |& tee -a $LOG_PATH

  if [[ -n $2 ]]; then
    echo -e -n "${COLOR_BLUE}[${APP_NAME}]${COLOR_NC} Installation of $1 completed. Do you want to proceed to $2 installation? (y/N): "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ [Yy] ]]; then
      execute "$2"
    else
      error "Installation of $2 aborted."
      exit 1
    fi
  fi
}

welcome ""

print_brake
echo -e "${COLOR_BOLD}${COLOR_BLUE}    MAIN MENU${COLOR_NC}"
print_brake

done=false
while [ "$done" == false ]; do
  options=(
    "Install the Panel"
    "Install Wings"
    "Install both [0] and [1] on the same machine"
    # "Uninstall panel or wings\n"

    "Install Panel ${COLOR_RED}(Beta)${COLOR_NC}"
    "Install Wings ${COLOR_RED}(Beta)${COLOR_NC}"
    "Install both [3] and [4] on the same machine"
    "Uninstall Panel or Wings ${COLOR_RED}(Beta)${COLOR_NC}"
  )

  actions=(
    "panel"
    "wings"
    "panel;wings"
    # "uninstall"

    "panel_canary"
    "wings_canary"
    "panel_canary;wings_canary"
    "uninstall_canary"
  )

  output "What would you like to do?"

  for i in "${!options[@]}"; do
    output "${COLOR_CYAN}[$i]${COLOR_NC} ${options[$i]}"
  done

  echo -e -n "${COLOR_YELLOW}* Input 0-$((${#actions[@]} - 1)): ${COLOR_NC}"
  read -r action

  [ -z "$action" ] && error "Input is required" && continue

  valid_input=("$(for ((i = 0; i <= ${#actions[@]} - 1; i += 1)); do echo "${i}"; done)")
  [[ ! " ${valid_input[*]} " =~ ${action} ]] && error "Invalid option"
  [[ " ${valid_input[*]} " =~ ${action} ]] && done=true && IFS=";" read -r i1 i2 <<<"${actions[$action]}" && execute "$i1" "$i2"
done

# Remove lib.sh, so next time the script is run the, newest version is downloaded.
rm -rf /tmp/lib.sh
