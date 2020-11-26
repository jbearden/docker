#! /usr/local/bin/bash

SYSTEM_DESKTOP_PICTURES='/System/Library/Desktop Pictures/'
COM_APPLE_DESKTOP_PLIST=$(locate 'com.apple.desktop.plist' | grep  ${USER})
OVERRIDE_PICTURE_PATH=$(defaults read "$COM_APPLE_DESKTOP_PLIST" override-picture-path CFBundleShortVersionString)

unset options i
let i=0
options=() # define working array
while read -r line; do # process file by file
        options[i++]="$line"
done < <( ls -1 "$SYSTEM_DESKTOP_PICTURES"  | grep jpg )

select opt in "${options[@]}" "QUIT"; do
  case $opt in
    *.jpg)
      echo "Desktop Picture selected: \"$opt\""
          DEFAULT_IMAGE_DIR=$(dirname $OVERRIDE_PICTURE_PATH)
          DEFAULT_IMAGE_NAME=$(basename $OVERRIDE_PICTURE_PATH)
          echo -n "Enter password for sudo rights: "
          read -s pass
          echo $pass | sudo -S cp -p  "$SYSTEM_DESKTOP_PICTURES$opt" "/$DEFAULT_IMAGE_DIR/$DEFAULT_IMAGE_NAME" && killall Dock
          echo $pass | sudo -S chown root:admin "/$OVERRIDE_PICTURE_PATH"
          exit
      # processing
      ;;
    "QUIT")
      echo "You chose to quit"
      break
      ;;
    *)
      echo "This is not a number"
      ;;
  esac
done
exit
