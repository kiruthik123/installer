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

# Check if script is loaded, load if not or fail otherwise.
fn_exists() { declare -F "$1" >/dev/null; }
if ! fn_exists lib_loaded; then
  # shellcheck source=lib/lib.sh
  source /tmp/lib.sh || source <(curl -sSL "$GITHUB_BASE_URL/$GITHUB_SOURCE"/lib/lib.sh)
  ! fn_exists lib_loaded && echo "* ERROR: Could not load lib script" && exit 1
fi

# ------------------ Variables ----------------- #

export RM_PANEL=false
export RM_WINGS=false

# --------------- Main functions --------------- #

main() {
  welcome ""

  if [ -d "/var/www/pterodactyl" ]; then
    output "Panel installation has been detected."
    echo -e -n "${COLOR_YELLOW}* Do you want to remove panel? (y/N): ${COLOR_NC}"
    read -r RM_PANEL_INPUT
    [[ "$RM_PANEL_INPUT" =~ [Yy] ]] && RM_PANEL=true
  fi

  if [ -d "/etc/pterodactyl" ]; then
    output "Wings installation has been detected."
    warning "This will remove all the servers!"
    echo -e -n "${COLOR_YELLOW}* Do you want to remove Wings (daemon)? (y/N): ${COLOR_NC}"
    read -r RM_WINGS_INPUT
    [[ "$RM_WINGS_INPUT" =~ [Yy] ]] && RM_WINGS=true
  fi

  if [ "$RM_PANEL" == false ] && [ "$RM_WINGS" == false ]; then
    error "Nothing to uninstall!"
    exit 1
  fi

  summary

  # confirm uninstallation
  echo -e -n "${COLOR_YELLOW}* Continue with uninstallation? (y/N): ${COLOR_NC}"
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    run_installer "uninstall"
  else
    error "Uninstallation aborted."
    exit 1
  fi
}

summary() {
  print_brake
  echo -e "${COLOR_BOLD}${COLOR_BLUE}SUMMARY${COLOR_NC}"
  print_brake
  output "${COLOR_CYAN}Uninstall panel?${COLOR_NC} $RM_PANEL"
  output "${COLOR_CYAN}Uninstall wings?${COLOR_NC} $RM_WINGS"
  print_brake
}

goodbye() {
  print_brake
  [ "$RM_PANEL" == true ] && output "${COLOR_RED}[-] Panel uninstallation completed${COLOR_NC}"
  [ "$RM_WINGS" == true ] && output "${COLOR_RED}[-] Wings uninstallation completed${COLOR_NC}"
  output "Thank you to ${COLOR_MAGENTA}${APP_NAME}${COLOR_NC}."
  print_brake
}

main
goodbye
