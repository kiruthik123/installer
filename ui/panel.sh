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

# Domain name / IP
export FQDN=""

# Default MySQL credentials
export MYSQL_DB=""
export MYSQL_USER=""
export MYSQL_PASSWORD=""

# Environment
export timezone=""
export email=""

# Initial admin account
export user_email=""
export user_username=""
export user_firstname=""
export user_lastname=""
export user_password=""

# Assume SSL, will fetch different config if true
export ASSUME_SSL=false
export CONFIGURE_LETSENCRYPT=false

# Firewall
export CONFIGURE_FIREWALL=false

# ------------ User input functions ------------ #

ask_letsencrypt() {
  if [ "$CONFIGURE_UFW" == false ] && [ "$CONFIGURE_FIREWALL_CMD" == false ]; then
    warning "Let's Encrypt requires port 80/443 to be opened! You have opted out of the automatic firewall configuration; use this at your own risk (if port 80/443 is closed, the script will fail)!"
  fi

  echo -e -n "${COLOR_YELLOW}* Do you want to automatically configure HTTPS using Let's Encrypt? (y/N): ${COLOR_NC}"
  read -r CONFIRM_SSL

  if [[ "$CONFIRM_SSL" =~ [Yy] ]]; then
    CONFIGURE_LETSENCRYPT=true
    ASSUME_SSL=false
  fi
}

ask_assume_ssl() {
  output "Let's Encrypt is not going to be automatically configured by this script (user opted out)."
  output "You can 'assume' Let's Encrypt, which means the script will download a nginx configuration that is configured to use a Let's Encrypt certificate but the script won't obtain the certificate for you."
  output "If you assume SSL and do not obtain the certificate, your installation will not work."
  echo -e -n "${COLOR_YELLOW}* Assume SSL or not? (y/N): ${COLOR_NC}"
  read -r ASSUME_SSL_INPUT

  [[ "$ASSUME_SSL_INPUT" =~ [Yy] ]] && ASSUME_SSL=true
  true
}

check_FQDN_SSL() {
  if [[ $(invalid_ip "$FQDN") == 1 && $FQDN != 'localhost' ]]; then
    SSL_AVAILABLE=true
  else
    warning "* Let's Encrypt will not be available for IP addresses."
    output "To use Let's Encrypt, you must use a valid ${COLOR_BOLD}domain name${COLOR_NC}."
  fi
}

main() {
  # check if we can detect an already existing installation
  if [ -d "/var/www/pterodactyl" ]; then
    warning "The script has detected that you already have Pterodactyl panel on your system! You cannot run the script multiple times, it will fail!"
    echo -e -n "${COLOR_YELLOW}* Are you sure you want to proceed? (y/N): ${COLOR_NC}"
    read -r CONFIRM_PROCEED
    if [[ ! "$CONFIRM_PROCEED" =~ [Yy] ]]; then
      error "Installation aborted!"
      exit 1
    fi
  fi

  welcome "panel"

  check_os_x86_64

  # set database credentials
  output "${COLOR_BOLD}Database Settings${COLOR_NC}"

  MYSQL_DB="-"
  while [[ "$MYSQL_DB" == *"-"* ]]; do
    required_input MYSQL_DB "Database Name [panel]: " "" "panel"
    [[ "$MYSQL_DB" == *"-"* ]] && error "Database name cannot contain hyphens"
  done

  MYSQL_USER="-"
  while [[ "$MYSQL_USER" == *"-"* ]]; do
    required_input MYSQL_USER "Database User [pterodactyl]: " "" "pterodactyl"
    [[ "$MYSQL_USER" == *"-"* ]] && error "Database user cannot contain hyphens"
  done

  # MySQL password input
  rand_pw=$(gen_passwd 64)
  password_input MYSQL_PASSWORD "Database Password [enter for random]: " "MySQL password cannot be empty" "$rand_pw"

  readarray -t valid_timezones <<<"$(curl -s "$GITHUB_URL"/configs/valid_timezones.txt)"
  output "List of valid timezones here $(hyperlink "https://www.php.net/manual/en/timezones.php")"

  while [ -z "$timezone" ]; do
    echo -e -n "${COLOR_YELLOW}* Timezone [Europe/Stockholm]: ${COLOR_NC}"
    read -r timezone_input

    array_contains_element "$timezone_input" "${valid_timezones[@]}" && timezone="$timezone_input"
    [ -z "$timezone_input" ] && timezone="Europe/Stockholm" # because köttbullar!
  done

  email_input email "Email Address: " "Email cannot be empty or invalid"
  user_email="$email"

  # Initial admin account
  required_input user_username "Admin Username: " "Username cannot be empty"
  required_input user_firstname "First Name: " "Name cannot be empty"
  required_input user_lastname "Last Name: " "Name cannot be empty"
  password_input user_password "Admin Password: " "Password cannot be empty"

  print_brake 72

  # set FQDN
  while [ -z "$FQDN" ]; do
    echo -e -n "${COLOR_YELLOW}* Set the FQDN of this panel (panel.example.com): ${COLOR_NC}"
    read -r FQDN
    [ -z "$FQDN" ] && error "FQDN cannot be empty"
  done

  # Check if SSL is available
  check_FQDN_SSL

  # Ask if firewall is needed
  ask_firewall CONFIGURE_FIREWALL

  # Only ask about SSL if it is available
  if [ "$SSL_AVAILABLE" == true ]; then
    # Ask if letsencrypt is needed
    ask_letsencrypt
    # If it's already true, this should be a no-brainer
    [ "$CONFIGURE_LETSENCRYPT" == false ] && ask_assume_ssl
  fi

  # verify FQDN if user has selected to assume SSL or configure Let's Encrypt
  [ "$CONFIGURE_LETSENCRYPT" == true ] || [ "$ASSUME_SSL" == true ] && bash <(curl -s "$GITHUB_URL"/lib/verify-fqdn.sh) "$FQDN"

  # summary
  summary

  # confirm installation
  echo -e -n "\n${COLOR_YELLOW}* Initial configuration completed. Continue with installation? (y/N): ${COLOR_NC}"
  read -r CONFIRM
  if [[ "$CONFIRM" =~ [Yy] ]]; then
    run_installer "panel"
  else
    error "Installation aborted."
    exit 1
  fi
}

summary() {
  print_brake
  echo -e "${COLOR_BOLD}${COLOR_BLUE}SUMMARY${COLOR_NC}"
  print_brake
  output "${APP_NAME} Panel ${COLOR_GREEN}$PTERODACTYL_PANEL_VERSION${COLOR_NC} with nginx on ${COLOR_MAGENTA}$OS${COLOR_NC}"
  output "${COLOR_CYAN}Database name:${COLOR_NC} $MYSQL_DB"
  output "${COLOR_CYAN}Database user:${COLOR_NC} $MYSQL_USER"
  output "${COLOR_CYAN}Database password:${COLOR_NC} (censored)"
  output "${COLOR_CYAN}Timezone:${COLOR_NC} $timezone"
  output "${COLOR_CYAN}Email:${COLOR_NC} $email"
  output "${COLOR_CYAN}User email:${COLOR_NC} $user_email"
  output "${COLOR_CYAN}Username:${COLOR_NC} $user_username"
  output "${COLOR_CYAN}First name:${COLOR_NC} $user_firstname"
  output "${COLOR_CYAN}Last name:${COLOR_NC} $user_lastname"
  output "${COLOR_CYAN}User password:${COLOR_NC} (censored)"
  output "${COLOR_CYAN}Hostname/FQDN:${COLOR_NC} $FQDN"
  output "${COLOR_CYAN}Configure Firewall?${COLOR_NC} $CONFIGURE_FIREWALL"
  output "${COLOR_CYAN}Configure Let's Encrypt?${COLOR_NC} $CONFIGURE_LETSENCRYPT"
  output "${COLOR_CYAN}Assume SSL?${COLOR_NC} $ASSUME_SSL"
  print_brake
}

goodbye() {
  print_brake 62
  output "${COLOR_GREEN}[+] Panel installation completed${COLOR_NC}"
  output ""

  [ "$CONFIGURE_LETSENCRYPT" == true ] && output "Your panel should be accessible from $(hyperlink "$FQDN")"
  [ "$ASSUME_SSL" == true ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && output "You have opted in to use SSL, but not via Let's Encrypt automatically. Your panel will not work until SSL has been configured."
  [ "$ASSUME_SSL" == false ] && [ "$CONFIGURE_LETSENCRYPT" == false ] && output "Your panel should be accessible from $(hyperlink "$FQDN")"

  output ""
  output "Installation is using nginx on ${COLOR_MAGENTA}$OS${COLOR_NC}"
  output "Thank you for choosing ${COLOR_MAGENTA}${APP_NAME}${COLOR_NC}."
  [ "$CONFIGURE_FIREWALL" == false ] && echo -e "* ${COLOR_RED}Note${COLOR_NC}: If you haven't configured the firewall: 80/443 (HTTP/HTTPS) is required to be open!"
  print_brake
}

# run script
main
goodbye
