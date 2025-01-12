#!/bin/bash
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Try \`sudo femto-meshtasticd-config\`."
   exit 1
fi

args="$@" # arguments to this script
interactive="true"
help=$(cat <<EOF
Arguments:
-h          This message
    Environment - must be first argument:
-x          User UI is not terminal (script interactive unavailable)
    Actions:
-i          Install
-u          Uninstall
-g          Upgrade
-e          Enable service, if applicable
-d          Disable service, if applicable
-s          Stop service
-r          Start/Restart
-l          Command to run software
    Information:
-N          Get name
-A          Get author
-D          Get description
-U          Get URL
-O          Get options supported by this script
-S          Get service status
-L          Get Install location
-C          Get Conflicts
-I          Check if installed. Returns an error if not installed
EOF
)

### For package maintainer:
# Fill the following fields and choose the options that are in use by this package
# Populate the install, uninstall and upgrade functions
# Remember that this script may be launched in terminal, via web UI or another method, so inputs aren't really possible
# Arguments to the script are stored in $args
# This system supports both interactive and non-interactive installs. For non-interactive installs, $interactive="false". In this cause special instructions to the user should be given as user_message, such as `After installation, edit /opt/software/config.ini`
# Successful operations should `exit 0`, fails should `exit 1`
# Messages to the user (such as configuration instructions, explanatory error messages, etc) should be given as: `echo "user_message: text"`
# Everything following `user_message: ` will be displayed prominently to the user, so it must the last thing echoed


name="Curses Client for Meshtastic"   # software name
author="pdxlocations"   # software author - OPTIONAL
description="Command line client using the curses library, powered by Meshtastic.org.\nAfter install, run \`curses\` to launch."   # software description - OPTIONAL (but strongly recommended!)
URL="https://github.com/pdxlocations/curses-client-for-meshtastic/"   # software URL. Can contain multiple URLs - OPTIONAL
options="xiuglNADUOLIto"   # script options in use by software package. For example, for a package with no service, exclude `edsr`
launch="python /opt/curses-client-for-meshtastic/main.py --host"   # command to launch software, if applicable
service_name=""   # the name of the service/s, such as `chrony`. REQUIRED if service options are in use. If multiple services, separate by spaces "service1 service2"
location="/opt/curses-client-for-meshtastic"   # install location REQUIRED if not apt installed. Generally, we use `/opt/software-name`
conflicts=""   # comma delineated plain-text list of packages with which this package conflicts. Blank if none. Use the name as it appears in the $name field of the other package. Extra plaintext is allowed, such as "packageA, packageB, any other software that uses the Meshtastic CLI"


if [ $# -eq 0 ]; then
  echo "No arguments provided."
  echo -e "$help"
  exit 1
fi


# install script
install() {
  if ! git clone https://github.com/pdxlocations/curses-client-for-meshtastic.git /opt/curses-client-for-meshtastic; then
    echo "user_message: Git clone failed. Is internet connected?"
    exit 1
  fi
  chown -R femto $location #give ownership of installation directory to $user
  git config --global --add safe.directory $location # prevents git error when updating
  echo "Creating \`curses\` shortcut."
  echo -e "#!/bin/bash\n$launch" | sudo tee /usr/local/bin/curses > /dev/null
  chmod +x /usr/local/bin/curses
  echo "user_message: To launch, run \`curses\`."
  exit 0 # should be `exit 1` if the installation failed
}


# uninstall script
uninstall() {
  rm -rf $location
  rm /usr/local/bin/curses
  echo "user_message: All files removed."
  exit 0 # should be `exit 1` if the installation failed
}

#upgrade script
upgrade() {
  cd $location
  if ! git pull; then
    echo "user_message: Git pull failed. Is internet connected?"
    exit 1
  fi
  exit 0
}


# Check if already installed. `exit 0` if yes, `exit 1` if no
check() {
  #the following works for cloned repos, but not for apt installs
  if [ -d "$location" ]; then
    #echo "Already installed"
    exit 0
  else
    #echo "Not installed"
    exit 1
  fi
}

while getopts ":h$options" opt; do
  case ${opt} in
    h) # Option -h (help)
      echo -e "$help"
      ;;
    x) # Option -x (no user interaction available)
      interactive="false"
      ;;
    i) # Option -i (install)
      install
      ;;
    u) # Option -u (uninstall)
      uninstall
      ;;
    g) # Option -g (upgrade)
      upgrade
      ;;
    e) # Option -e (Enable service, if applicable)
      systemctl enable $service_name
      ;;
    d) # Option -d (Disable service, if applicable)
      systemctl disable $service_name
      ;;
    s) # Option -s (Stop service)
      systemctl stop $service_name
      ;;
    r) # Option -r (Start/Restart)
      systemctl restart $service_name
      ;;
    l) # Option -l (Run software)
      echo "Launching $name..."
      sudo -u ${SUDO_USER:-$(whoami)} $launch 
      ;;
    N) echo -e $name ;;
    A) echo -e $author ;;
    D) echo $description ;;
    U) echo -e $URL ;;
    O) echo -e $options ;;
    S) # Option -S (Get service status)
      systemctl status $service_name
    ;;
    L) echo -e $location ;;
    C) echo -e $conflicts ;;
    I) # Option -I (Check if already installed)
      check
    ;;
  esac
done

exit 0