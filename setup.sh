#!/bin/bash

set -e

source ./.env
source ./repo.env

DATADIR=./dbData
SRCDIR=src

RESET='\033[0m' # No Color
RED='\033[0;31m'
BLK='\033[0;30m'
GRN='\033[0;32m'
BRN='\033[0;33m'
BLU='\033[0;34m'
PRP='\033[0;35m'
CYN='\033[0;36m'
LGRY='\033[0;37m'

YEL='\033[1;33m'
WHT='\033[1;37m'
DGRY='\033[1;30m'
LRED='\033[1;31m'
LGRN='\033[1;32m'
LBLU='\033[1;34m'
LPRP='\033[1;35m'
LCYN='\033[1;36m'

BOLD="\033[1m"

configure_folder_if_missing() {
  declare NEW_FLDR=$1

  if [ ! -d $(pwd)/"$NEW_FLDR" ];
  then
    mkdir $(pwd)/"$NEW_FLDR"
#    touch $(pwd)/"$NEW_FLDR"/.gitkeep
  fi

  if is_windows_environment ; then
    # If on Windows - make filesystem case sensitive
    fsutil.exe file SetCaseSensitiveInfo $(pwd)/"$NEW_FLDR" enable
  fi
}

set_up_apache_vhosts() {
  declare LOCALHOST_IP=$1
  declare LOCALHOST_DOMAIN=$2
  declare HOSTS_FILE=$3

  local APACHE_VHOST
  APACHE_VHOST="${LOCALHOST_IP} ${LOCALHOST_DOMAIN}"

  echo -e "${BRN}Setting up ${LOCALHOST_DOMAIN} once ...${RESET}"
  echo "$APACHE_VHOST" >> $HOSTS_FILE
  echo -e "${BRN} ... Done...${RESET}"
}

postprocess_fix_db_creds_in_jmla_config() {
  if is_windows_environment; then
    sed -i "s#\(\$host = '\).*\('\)#\1$JOOMLA_DB_HOST\2#" "$SRCDIR"/configuration.php;
    sed -i "s#\(\$db = '\).*\('\)#\1$JOOMLA_DB_NAME\2#" "$SRCDIR"/configuration.php;
    sed -i "s#\(\$password = '\).*\('\)#\1$JOOMLA_DB_PASSWORD\2#" "$SRCDIR"/configuration.php;
    sed -i "s#\(\$user = '\).*\('\)#\1$JOOMLA_DB_USER\2#" "$SRCDIR"/configuration.php;
    sed -i "s#\(\$force_ssl = '\).*\('\)#\1$JOOMLA_FORCE_SSL\2#" "$SRCDIR"/configuration.php;
    sed -i "s#\(\$log_path = '\).*\('\)#\1$JOOMLA_LOG_PATH_CONTAINER\2#" "$SRCDIR"/configuration.php;
    sed -i "s#\(\$tmp_path = '\).*\('\)#\1$JOOMLA_TMP_PATH\2#" "$SRCDIR"/configuration.php;
  else
    sed -i '.bak' "s#\(\$host = '\).*\('\)#\1$JOOMLA_DB_HOST\2#" "$SRCDIR"/configuration.php;
    sed -i '.bak' "s#\(\$db = '\).*\('\)#\1$JOOMLA_DB_NAME\2#" "$SRCDIR"/configuration.php;
    sed -i '.bak' "s#\(\$password = '\).*\('\)#\1$JOOMLA_DB_PASSWORD\2#" "$SRCDIR"/configuration.php;
    sed -i '.bak' "s#\(\$user = '\).*\('\)#\1$JOOMLA_DB_USER\2#" "$SRCDIR"/configuration.php;
    sed -i '.bak' "s#\(\$force_ssl = '\).*\('\)#\1$JOOMLA_FORCE_SSL\2#" "$SRCDIR"/configuration.php;
    sed -i '.bak' "s#\(\$log_path = '\).*\('\)#\1$JOOMLA_LOG_PATH_CONTAINER\2#" "$SRCDIR"/configuration.php;
    sed -i '.bak' "s#\(\$tmp_path = '\).*\('\)#\1$JOOMLA_TMP_PATH\2#" "$SRCDIR"/configuration.php;
  fi

  local SED_CHECK_host
  SED_CHECK_host=$(cat $(pwd)/"$SRCDIR"/configuration.php | grep '$host ')
  echo "SED_CHECK_host $SED_CHECK_host"

  local SED_CHECK_user
  SED_CHECK_user=$(cat $(pwd)/"$SRCDIR"/configuration.php | grep '$user ')
  echo "SED_CHECK_user $SED_CHECK_user"

  local SED_CHECK_password
  SED_CHECK_password=$(cat $(pwd)/"$SRCDIR"/configuration.php | grep '$password ')
  echo "SED_CHECK_password $SED_CHECK_password"

  local SED_CHECK_db
  SED_CHECK_db=$(cat $(pwd)/"$SRCDIR"/configuration.php | grep '$db ')
  echo "SED_CHECK_db $SED_CHECK_db"

  local SED_CHECK_force_ssl
  SED_CHECK_force_ssl=$(cat $(pwd)/"$SRCDIR"/configuration.php | grep '$force_ssl ')
  echo "SED_CHECK_force_ssl $SED_CHECK_force_ssl"

  local SED_CHECK_logpath
  SED_CHECK_logpath=$(cat $(pwd)/"$SRCDIR"/configuration.php | grep '$log_path ')
  echo "SED_CHECK_logpath $SED_CHECK_logpath"

  local SED_CHECK_tmp_path
  SED_CHECK_tmp_path=$(cat $(pwd)/"$SRCDIR"/configuration.php | grep '$tmp_path ')
  echo "SED_CHECK_tmp_path $SED_CHECK_tmp_path"
}

clone_repo() {
  # first ensure the destination is empty
  echo "----- deleting content of $SRCDIR folder ..."

  if [ -d "$SRCDIR" ];
  then
    rm -rf "$SRCDIR"
  fi

  configure_folder_if_missing ./"$SRCDIR"

  echo "----- executing [git clone -b $TARGET_BRANCH $SRC_REPO $SRCDIR]"
  git clone -b $TARGET_BRANCH $SRC_REPO $SRCDIR
}

remove_install_folder() {
  if [ -d "$SRCDIR"/installation ];
  then
    echo "----- deleting $SRCDIR/installation folder ..."
    rm -rf "$SRCDIR"/installation
  else
    echo "----- $SRCDIR/installation folder not found ..."
  fi
}

ensure_akeeba_bkp_zips_present() {
  local AKEEBA_BKP
  AKEEBA_BKP=$(find ./bkp -iname *utc.zip)
  local DB_DUMP_FILE
  DB_DUMP_FILE=$(find ./bkp -iname *utc.sql)

  if ! [ -f "$AKEEBA_BKP" ];
  then
    echo "----- Akeeba backup zip file expected in [$(pwd)/bkp] folder, but not found"
    exit
  fi

  if ! [ -f "$DB_DUMP_FILE" ];
  then
    echo "----- Akeeba db dump sql file expected in [$(pwd)/bkp] folder, but not found"
    exit
  fi
}

extract_akeeba_bkp() {
  local AKEEBA_BKP
  AKEEBA_BKP=$(find ./bkp -iname *utc.zip)

  if [ -f "$AKEEBA_BKP" ];
  then
    echo $AKEEBA_BKP
    unzip -o $AKEEBA_BKP -d $SRCDIR
  else
    echo "----- Akeeba backup zip file expected in [$(pwd)/bkp] folder, but not found"
    exit
  fi
}

postprocess_disable_plugins() {
  echo "----- running [ php $(pwd)/bin/scripts/disable_plugins.php "127.0.0.1" $JOOMLA_DB_USER $JOOMLA_DB_PASSWORD $JOOMLA_DB_NAME ]"
  php "${PWD}"/bin/scripts/disable_plugins.php "127.0.0.1" "$JOOMLA_DB_USER" "$JOOMLA_DB_PASSWORD" "$JOOMLA_DB_NAME"
}

postprocess_add_to_super_admin_group() {
  declare JOOMLA_USERNM=$1
  declare JOOMLA_SUPER_ID=$2

  echo "----- running [ php $(pwd)/bin/scripts/add_to_joomla_group.php "127.0.0.1" $JOOMLA_DB_USER $JOOMLA_DB_PASSWORD $JOOMLA_DB_NAME $JOOMLA_USERNM $JOOMLA_SUPER_ID]"
  php "${PWD}"/bin/scripts/add_to_joomla_group.php "127.0.0.1" "$JOOMLA_DB_USER" "$JOOMLA_DB_PASSWORD" "$JOOMLA_DB_NAME" "$JOOMLA_USERNM" "$JOOMLA_SUPER_ID"
}

is_windows_environment() {
  if [ "$OSTYPE" == "msys" ] || [ "$OSTYPE" == "cygwin" ]
  then
    return 0  # means "is Windows" (when called in if)
  else
    return 1
  fi
}

is_root_user() {
  if [ "$EUID" -ne 0 ]
  then
    return 1
  else
    return 0 # means "is root" (when called in if)
  fi
}

trim_and_upcase() {
  declare UNTRIMMED=$1
  echo -e "$UNTRIMMED" | xargs | tr '[:lower:]' '[:upper:]'
}

pre_setup_checks() {
  local HOSTS_FILE
  HOSTS_FILE='/etc/hosts';

  if is_windows_environment; then
    HOSTS_FILE='/c/Windows/System32/drivers/etc/hosts'
  fi

  local LOCALHOST_IP
  LOCALHOST_IP="127.0.0.1"

  local RGX_LOCALHOST_IP
  if is_windows_environment; then
    RGX_LOCALHOST_IP=$(echo "$LOCALHOST_IP" | sed -r 's#\.#\\.#g')
  else
    RGX_LOCALHOST_IP=$(echo "$LOCALHOST_IP" | sed 's#\.#\\.#g')
  fi

  local RGX_DOMAIN
  if is_windows_environment; then
    RGX_DOMAIN=$(echo "$LOCALHOST_DOMAIN" | sed -r 's#\.#\\.#g')
  else
    RGX_DOMAIN=$(echo "$LOCALHOST_DOMAIN" | sed 's#\.#\\.#g')
  fi

  if grep -qiE "^[^#]*${RGX_LOCALHOST_IP}[ \t]+${RGX_DOMAIN}[ \t\r\n]*$" $HOSTS_FILE;
  then
    echo -e ">>>>>>>>>>>>> ${GRN}${LOCALHOST_DOMAIN} found in your hosts file .. ${RESET}"
    if ! is_windows_environment && is_root_user; then
        echo -e "              ${RED}You no longer need to run setup as root             ${RESET}"
        echo -e " - rerun script with ${LBLU}bash setup.sh${RESET}, exiting..."
        exit
    fi
  else
    echo -e "${RED}${LOCALHOST_DOMAIN} is not yet set up in your hosts file${RESET}"

    if is_windows_environment; then
      set_up_apache_vhosts "$LOCALHOST_IP" "$LOCALHOST_DOMAIN" "$HOSTS_FILE"
    else
      if is_root_user; then
        set_up_apache_vhosts "$LOCALHOST_IP" "$LOCALHOST_DOMAIN" "$HOSTS_FILE"
        echo -e "Elevated privileges no longer needed..."
        echo -e " please rerun script with ${LBLU}bash setup.sh${RESET}, exiting..."
      else
        echo -e "${BRN}You need to rerun this script as root (one-time) to do that${RESET}"
        echo -e " - rerun script with ${LBLU}sudo bash setup.sh${RESET}, exiting..."
      fi
      exit
    fi
  fi
}

#########################################################################################
#########################################################################################
echo -e "${LBLU}>>>>>>>>>>>>> SETUP SCRIPT - best run from your PHPStorm (or other IDE) terminal) ...${RESET}"

pre_setup_checks

#########################################################################################
read -p "$(echo -e "--- "$BRN"Step 1/10"$RESET" - create required folders if missing? [Y/n] ")" CREATE_REQUIRED_FOLDERS
CREATE_REQUIRED_FOLDERS=$(trim_and_upcase "${CREATE_REQUIRED_FOLDERS:-Y}")

if [ "$CREATE_REQUIRED_FOLDERS" == 'Y' ];
then
  configure_folder_if_missing $DATADIR
fi

##########################################################################################
ensure_akeeba_bkp_zips_present

##########################################################################################
echo -e "--- "$BRN"Step 2/10"$RESET" - about to clone repo - "
read -p "$(echo -e "    "$RED"THIS WILL DELETE EXISTING FILES IN src FOLDER"$RESET", proceed? [y/N] ")" CLONE_REPO
CLONE_REPO=$(trim_and_upcase "${CLONE_REPO:-N}")

if [ "$CLONE_REPO" == 'Y' ];
then
  clone_repo
fi

##########################################################################################
echo -e "--- "$BRN"Step 3/10"$RESET" - about to extract Akeeba Bkp - "
read -p "$(echo -e "    "$RED"THIS WILL OVERWRITE REPO FILES"$RESET", proceed? [Y/n] ")" EXTRACT_AKEEBA_BKP
EXTRACT_AKEEBA_BKP=$(trim_and_upcase "${EXTRACT_AKEEBA_BKP:-Y}")

if [ "$EXTRACT_AKEEBA_BKP" == 'Y' ];
then
  extract_akeeba_bkp
fi

##########################################################################################
read -p "$(echo -e "--- "$BRN"Step 4/10"$RESET" - about to [ git reset --hard ], proceed? [Y/n] ")" DO_GIT_RESET_HARD
DO_GIT_RESET_HARD=$(trim_and_upcase "${DO_GIT_RESET_HARD:-Y}")

if [ "$DO_GIT_RESET_HARD" == 'Y' ];
then
  BASE_DIR=$(pwd)
  cd "$SRCDIR"
  git reset --hard
  cd "$BASE_DIR"
fi

##########################################################################################
echo -e "--- "$BRN"Step 5/10"$RESET" - about to gitignore untracked git files using [ git status --porcelain ... ] - "
read -p "$(echo -e "    "$RED"PLEASE REMEMBER TO LEAVE THE .gitignore FILE OUT OF YOUR COMMITS AFTER THIS CHANGE"$RESET", proceed? [y/N] ")" DO_FILE_CLEANUP
DO_FILE_CLEANUP=$(trim_and_upcase "${DO_FILE_CLEANUP:-N}")

if [ "$DO_FILE_CLEANUP" == 'Y' ];
then
  BASE_DIR=$(pwd)
  cd "$SRCDIR"

  # basic cleanup of dangling files
  git status --porcelain | grep '^??' | cut -c4- >> .gitignore
  echo ".htaccess" >> .gitignore
  echo "modules/mod_universal_ajaxlivesearch/cache/*" >> .gitignore
  echo "administrator/cache/com_rsfirewall" >> .gitignore

  if is_windows_environment; then
    sed -i "s#^api#/api#" .gitignore   # ignore /api but not plugins/api/payroll/
  else
    sed -i '.bak' "s#^api#/api#" .gitignore   # ignore /api but not plugins/api/payroll/
  fi

  echo -e "${LBLU}    The change made to .gitignore is a hack${RESET}"
  echo -e "${LBLU}    so that you dont see a whole bunch of untracked files${RESET}"
  echo -e "${LBLU}    meaning you would need to keep .gitignore out of your commits${RESET}"
  echo -e "${LBLU}    or if you need to modify .gitignore first do [ git checkout .gitignore ]${RESET}"

  cd "$BASE_DIR"
fi

##########################################################################################
read -p "$(echo -e "--- "$BRN"Step 6/10"$RESET" - about to disable default Joomla installer (Akeeba edition), proceed? [Y/n] ")" DELETE_AKEEBA_INSTALL
DELETE_AKEEBA_INSTALL=$(trim_and_upcase "${DELETE_AKEEBA_INSTALL:-Y}")

if [ "$DELETE_AKEEBA_INSTALL" == 'Y' ];
then
  remove_install_folder
fi

##########################################################################################
# run docker-compose up with build flag
read -p "$(echo -e "--- "$BRN"Step 7/10"$RESET" - about to rebuild docker image, proceed? [y/N] ")" REBUILD_DOCKER_IMG
REBUILD_DOCKER_IMG=$(trim_and_upcase "${REBUILD_DOCKER_IMG:-N}")

if [ "$REBUILD_DOCKER_IMG" == 'Y' ];
then
  echo -e "--- If this is a re-run of setup.sh, and you have an existing db, do you want to replace that db with a fresh one?"
  read -p "$(echo -e "    "$RED"THIS CLEARS THE DB FOLDER BEFORE REBUILDING THE DOCKER IMAGES"$RESET" [y/N] ")" LOAD_FRESH_DB
  LOAD_FRESH_DB=$(trim_and_upcase "${LOAD_FRESH_DB:-N}")

  if [ "$LOAD_FRESH_DB" == 'Y' ];
  then
   # rm -rf "$DATADIR:?/*"
   if [ -d $DATADIR ]; then
      DATE=$(date '+%Y-%m-%d-%s')
      DATADIR_NAME=$(sed  's/[./]*//' <<< $DATADIR ) # remove leading './'
      $(mv ${DATADIR_NAME} ${DATADIR_NAME}.${DATE} ) # rename/archive dbData dir.
   fi
  fi

  if is_windows_environment; then
    dos2unix bin/apache2/joomla-entrypoint.sh
  #  dos2unix bin/apache2/wait-for
    dos2unix bin/apache2/makedb.php
    dos2unix bin/scripts/disable_plugins.php
    dos2unix bin/scripts/add_to_joomla_group.php
  fi

  docker-compose down
  sleep 3 # we dont want to attempt creating a container when its outgoing duplicate still exists
  docker-compose up -d --build
  echo -e "${LBLU} >>> Please wait while mysql tables are created in dbData/usxpress ...${RESET}"
  echo -e "${LBLU} >>> Do not proceed with the next step until you see the "datph_weblinks.ibd" file in dbData/usxpress folder..${RESET}"
  echo -e "${LBLU}     OR just wait about 2 minutes...${RESET}"
  echo -e "${LBLU} >>> If no tables are created at all, manually create the tables by connecting to the database (e.g from your IDE)${RESET}"
  echo -e "${LBLU}     and running the .sql script in bkp/ folder, then you can proceed with the next step ${RESET}"
  sleep $MARIADB_TBL_CREATION_WAIT   # mariadb initialization may take some time
fi

#########################################################################################
read -p "$(echo -e "--- "$BRN"Step 8/10"$RESET" - about to update db creds in joomla config, proceed? [Y/n] ")" FIX_DB_CREDS
FIX_DB_CREDS=$(trim_and_upcase "${FIX_DB_CREDS:-Y}")

if [ "$FIX_DB_CREDS" == 'Y' ];
then
  postprocess_fix_db_creds_in_jmla_config
fi

#########################################################################################
read -p "$(echo -e "--- "$BRN"Step 9/10"$RESET" - about to disable logincrypt, rsFirewall and 2-factor auth plugins, proceed? [Y/n] ")" DISABLE_PLUGINS
DISABLE_PLUGINS=$(trim_and_upcase "${DISABLE_PLUGINS:-Y}")

if [ "$DISABLE_PLUGINS" == 'Y' ];
then
  postprocess_disable_plugins
fi

#########################################################################################
read -p "$(echo -e "--- "$BRN"Step 10/10"$RESET" - would you like to upgrade yourself to a Joomla Super Admin? [Y/n] ")" UPGRADE_TO_ADMIN
UPGRADE_TO_ADMIN=$(trim_and_upcase "${UPGRADE_TO_ADMIN:-Y}")

if [ "$UPGRADE_TO_ADMIN" == 'Y' ];
then
  read -p "$(echo -e "--- What is your username when logging onto joomla dev admin backend: ")" DEV_USERNAME
  DEV_USERNAME=$(trim_and_upcase "$DEV_USERNAME")

  echo "--- Adding $DEV_USERNAME to Super Admin Group"
  postprocess_add_to_super_admin_group "$DEV_USERNAME" "$JOOMLA_SUPERADMIN_GROUP_ID"
fi

##########################################################################################
##########################################################################################
##########################################################################################
echo -e "${LBLU}>>>>>>>>>>>>> SETUP DONE...${RESET}"
echo -e "${LBLU}--- you can now click here http://usxpress2.com to view site ...${RESET}"
echo -e "${LBLU}--- and click here http://usxpress2.com:1080/ to view mailcatcher ...${RESET}"
echo -e ">>>>>>>>>>>>> in future you can run: ${GRN}docker-compose up -d${RESET} in this folder to start containers"
echo -e ">>>>>>>>>>>>> for now you can just do ${GRN}cd src${RESET} to enter the Joomla source folder"
echo -e ">>>>>>>>>>>>> more info in the README file"
