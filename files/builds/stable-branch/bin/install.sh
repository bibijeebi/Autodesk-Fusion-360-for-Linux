#!/usr/bin/env bash

####################################################################################################
# Name:         Autodesk Fusion 360 - Setup Wizard (Linux)                                         #
# Description:  With this file you can install Autodesk Fusion 360 on Linux.                       #
# Author:       Steve Zabka                                                                        #
# Author URI:   https://cryinkfly.com                                                              #
# License:      MIT                                                                                #
# Copyright (c) 2020-2024                                                                          #
# Time/Date:    20:40/31.07.2024                                                                   #
# Version:      1.9.13                                                                              #
####################################################################################################

# Path: /$HOME/.fusion360/bin/install.sh

###############################################################################################################################################################
# DESCRIPTION IN DETAIL                                                                                                                                       #
###############################################################################################################################################################
# With the help of my setup wizard, you will be given a way to install Autodesk Fusion 360 with some extensions on                                            #
# Linux so that you don't have to use Windows or macOS for this program in the future!                                                                        #
#                                                                                                                                                             #
# Also, my setup wizard will guides you through the installation step by step and will install some required packages.                                        #
#                                                                                                                                                             #
# The next one is you have the option of installing the program directly on your system or you can install it on an external storage medium.                  #
#                                                                                                                                                             #
# But it's important to know, you must to purchase the licenses directly from the manufacturer of Autodesk Fusion 360, when you will work with them on Linux! #
###############################################################################################################################################################

###############################################################################################################################################################
# THE INITIALIZATION OF DEPENDENCIES STARTS HERE:                                                                                                             #
###############################################################################################################################################################

# Default-Path:
SP_PATH="$HOME/.fusion360"

# Reset the graphics driver value:
WP_DRIVER="DXVK"

# Reset the logfile-value for the installation of Autodesk Fusion 360!
SP_FUSION360_CHANGE=0

REQUIRED_COMMANDS=(
    "yad"
    "wget"
)

# URL to download Fusion360Installer.exe
#SP_FUSION360_INSTALLER_URL="https://dl.appstreaming.autodesk.com/production/installers/Fusion%20360%20Admin%20Install.exe" <-- Old Link!!!
SP_FUSION360_INSTALLER_URL="https://dl.appstreaming.autodesk.com/production/installers/Fusion%20Client%20Downloader.exe"

# URL to download Microsoft Edge WebView2.Exec
SP_WEBVIEW2_INSTALLER_URL="https://github.com/aedancullen/webview2-evergreen-standalone-installer-archive/releases/download/109.0.1518.78/MicrosoftEdgeWebView2RuntimeInstallerX64.exe"

###############################################################################################################################################################

function SP_CHECK_REQUIRED_COMMANDS {
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        echo "Testing presence of ${cmd} ..."
        local path="$(command -v "${cmd}")"
        if [ -n "${path}" ]; then
            echo "Found: ${path}"
        else
            echo "No ${cmd} found in \$PATH!"
            exit 1
        fi
    done
}

function SP_STRUCTURE {
  mkdir -p "$SP_PATH/bin"
  mkdir -p "$SP_PATH/logs"
  mkdir -p "$SP_PATH/config"
  mkdir -p "$SP_PATH/graphics"
  mkdir -p "$SP_PATH/downloads"
  mkdir -p "$SP_PATH/extensions"
  mkdir -p "$SP_PATH/wineprefixes/default" # Fixes a bug in the standard installation routine!
  mkdir -p "$SP_PATH/locale/cs-CZ"
  mkdir -p "$SP_PATH/locale/de-DE"
  mkdir -p "$SP_PATH/locale/en-US"
  mkdir -p "$SP_PATH/locale/es-ES"
  mkdir -p "$SP_PATH/locale/fr-FR"
  mkdir -p "$SP_PATH/locale/it-IT"
  mkdir -p "$SP_PATH/locale/ja-JP"
  mkdir -p "$SP_PATH/locale/ko-KR"
  mkdir -p "$SP_PATH/locale/zh-CN"
  # Create a temporary folder with some information for the next step:
  mkdir -p /tmp/fusion360
  echo "English" > /tmp/fusion360/settings.txt
  echo "DXVK" >> /tmp/fusion360/settings.txt
  echo "English" > "$SP_PATH/config/settings.txt"
  echo "DXVK" >> "$SP_PATH/config/settings.txt"
}

###############################################################################################################################################################
# ALL LOG-FUNCTIONS ARE ARRANGED HERE:                                                                                                                        #
###############################################################################################################################################################

# Provides information about setup actions during installation.
function SP_LOGFILE_INSTALL {
  exec 5> "$SP_PATH/logs/setupact.log"
  BASH_XTRACEFD="5"
  set -x
}

###############################################################################################################################################################

# Check if already exists a Autodesk Fusion 360 installation on your system.
function SP_LOGFILE_WINEPREFIX_CHECK {
  SP_FUSION360_WINEPREFIX_CHECK="$SP_PATH/logs/wineprefixes.log" # Search for wineprefixes.log
  if [ -f "$SP_FUSION360_WINEPREFIX_CHECK" ]; then
    cp "$SP_FUSION360_WINEPREFIX_CHECK" "/tmp/fusion360/logs"
    SP_LOGFILE_WINEPREFIX_INFO # Add/Modify or Delete a exists Wineprefix of Autodesk Fusion 360.
  else
    SP_INSTALLDIR # Add a new Wineprefix of Autodesk Fusion 360.
  fi
}

###############################################################################################################################################################

# Create a WP-TYPE for the .desktop-files:
function SP_GET_WINEPREFIX_TYPE {
  if [[ $WP_DIRECTORY = "$SP_PATH/wineprefixes/default" ]]; then
    WP_TYPE="default"
  else
    # Create the directory (custom, custom-1, custom-2, ...)
    SP_ADD_CUSTOM_WINEPREFIX_TYPE
  fi
}

function SP_ADD_CUSTOM_WINEPREFIX_TYPE {
  WP_TYPE="custom"
  if [[ -e $WP_TYPE || -L $WP_TYPE ]] ; then
    i=0
    while [[ -e $WP_TYPE-$i || -L $WP_TYPE-$i ]] ; do
        (( i++ ))
    done
    WP_TYPE=$WP_TYPE-$i
  fi
}

###############################################################################################################################################################

function SP_LOGFILE_WINEPREFIX {
if [ $SP_FUSION360_CHANGE -eq 1 ]; then
  echo "FALSE" >> "$SP_PATH/logs/wineprefixes.log"
  echo "$WP_TYPE" >> "$SP_PATH/logs/wineprefixes.log"
  echo "$WP_DRIVER" >> "$SP_PATH/logs/wineprefixes.log"
  echo "$WP_DIRECTORY" >> "$SP_PATH/logs/wineprefixes.log"
fi
}

###############################################################################################################################################################

function SP_INSTALLDIR_CHECK {
# Check if this wineprefix already exist or not!
WP_PATH_CHECK="$WP_DIRECTORY/box-run.sh"
if [[ -f "$WP_PATH_CHECK" ]]; then
    echo "FALSE"
    SP_INSTALLDIR_INFO
else
    echo "TRUE"
    SP_FUSION360_CHANGE=1
    SP_WINE_SETTINGS
fi
}

###############################################################################################################################################################

function SP_CHECK_WINE_VERSION {
    #Wine version checking, warn user if their wine install is out of date
    WINE_VERSION="$(wine --version  | cut -d ' ' -f1 | sed -e 's/wine-//' -e 's/-rc.*//')"
    WINE_VERSION_SERIES="$(echo $WINE_VERSION | cut -d '.' -f1)"
    WINE_VERSION_SERIES_RELEASE="$(echo $WINE_VERSION | cut -d '.' -f2)"

    WINE_VERSION_MINIMUM=9.8
    WINE_VERSION_SERIES_MINIMUM=9
    WINE_VERSION_SERIES_RELEASE_MINIMUM=8
    
    if [ $WINE_VERSION_SERIES -lt $WINE_VERSION_SERIES_MINIMUM ]; then
        # Wine was below the needed series - no need to check anything else.
        echo "Your version of wine ${WINE_VERSION} is too old and will not work with Autodesk Fusion. You should upgrade to at least ${WINE_VERSION_MINIMUM}"
        SP_OS_SETTINGS
    elif [ $WINE_VERSION_SERIES -eq $WINE_VERSION_SERIES_MINIMUM ] && [ $WINE_VERSION_SERIES_RELEASE -lt $WINE_VERSION_SERIES_RELEASE_MINIMUM ]; then
        # Wine is the same series as the minimum requirement, but the dot release was below the minimum.
        echo "Your version of wine ${WINE_VERSION} is too old and will not work with Autodesk Fusion. You should upgrade to at least ${WINE_VERSION_MINIMUM}"
        SP_OS_SETTINGS
    else
        SP_FUSION360_INSTALL
    fi
}

###############################################################################################################################################################
# ALL LOCALE-FUNCTIONS ARE ARRANGED HERE:                                                                                                                     #
###############################################################################################################################################################

# Load the index of locale files:
function SP_LOCALE_INDEX {
  wget -NP "$SP_PATH/locale" https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/builds/stable-branch/locale/locale.sh
  chmod +x "$SP_PATH/locale/locale.sh"
  # shellcheck source=../locale/locale.sh
  source "$SP_PATH/locale/locale.sh"
  source "$SP_PATH/locale/en-US/locale-en.sh"
}

# Czech:
function SP_LOCALE_CS {
  # shellcheck source=../locale/cs-CZ/locale-cs.sh
  source "$SP_PATH/locale/cs-CZ/locale-cs.sh"
}

# German:
function SP_LOCALE_DE {
  # shellcheck source=../locale/de-DE/locale-de.sh
  source "$SP_PATH/locale/de-DE/locale-de.sh"
}

# English:
function SP_LOCALE_EN {
  # shellcheck source=../locale/en-US/locale-en.sh
  source "$SP_PATH/locale/en-US/locale-en.sh"
}

# Spanish:
function SP_LOCALE_ES {
  # shellcheck source=../locale/es-ES/locale-es.sh
  source "$SP_PATH/locale/es-ES/locale-es.sh"
}

# French:
function SP_LOCALE_FR {
  # shellcheck source=../locale/fr-FR/locale-fr.sh
  source "$SP_PATH/locale/fr-FR/locale-fr.sh"
}


# Italian:
function SP_LOCALE_IT {
  # shellcheck source=../locale/it-IT/locale-it.sh
  source "$SP_PATH/locale/it-IT/locale-it.sh"
}

# Japanese:
function SP_LOCALE_JA {
  # shellcheck source=../locale/ja-JP/locale-ja.sh
  source "$SP_PATH/locale/ja-JP/locale-ja.sh"
}

# Korean:
function SP_LOCALE_KO {
  # shellcheck source=../locale/ko-KR/locale-ko.sh
  source "$SP_PATH/locale/ko-KR/locale-ko.sh"
}

# Chinese:
function SP_LOCALE_ZH {
  # shellcheck source=../locale/zh-CN/locale-zh.sh
  source "$SP_PATH/locale/zh-CN/locale-zh.sh"
}

###############################################################################################################################################################

function SP_LOCALE_SETTINGS {
SP_LOCALE=$(awk 'NR == 1' /tmp/fusion360/settings.txt)
case "$SP_LOCALE" in
  "Czech")
    echo "CS"
    SP_LOCALE_CS
    ;;
  "English")
    echo "EN"
    SP_LOCALE_EN
    ;;
  "German")
    echo "DE"
    SP_LOCALE_DE
    ;;
  "Spanish")
    echo "ES"
    SP_LOCALE_ES
    ;;
  "French")
    echo "FR"
    SP_LOCALE_FR
    ;;
  "Italian")
    echo "IT"
    SP_LOCALE_IT
    ;;
  "Japanese")
    echo "JP"
    SP_LOCALE_JP
    ;;
  "Korean")
    echo "KO"
    SP_LOCALE_KO
    ;;
  "Chinese")
    echo "ZH"
    SP_LOCALE_ZH
    ;;
  *)
    echo "EN"
    SP_LOCALE_EN
    ;;
esac
}

###############################################################################################################################################################
# DONWLOAD WINETRICKS, AUTODESK FUSION 360 AND WEBVIEW2:                                                                                                                #
###############################################################################################################################################################

# Load the newest winetricks version:
function SP_WINETRICKS_LOAD {
  wget -Nc -P "$SP_PATH/bin" https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
  chmod +x "$SP_PATH/bin/winetricks"
}

###############################################################################################################################################################

# Load newest Autodesk Fusion 360 installer version for the Setup Wizard!
function SP_FUSION360_INSTALLER_LOAD {
  # Search for a existing installer of Autodesk Fusion 360
  FUSION360_INSTALLER="$SP_PATH/downloads/Fusion360installer.exe"
  if [ -f "$FUSION360_INSTALLER" ]; then
    echo "The Autodesk Fusion 360 installer exist!"
  else
    echo "The Autodesk Fusion 360 installer doesn't exist and will be downloaded for you!"
    wget "$SP_FUSION360_INSTALLER_URL" -cO Fusion360installer.exe
    mv "Fusion360installer.exe" "$SP_PATH/downloads/Fusion360installer.exe"
  fi
}

###############################################################################################################################################################

# Load newest WebView2 installer version for the Setup Wizard!
function SP_WEBVIEW2_INSTALLER_LOAD {
  # Search for a existing installer of WEBVIEW2
  WEBVIEW2_INSTALLER="$SP_PATH/downloads/WebView2installer.exe"
  if [ -f "$WEBVIEW2_INSTALLER" ]; then
    echo "The WebView2installer installer exist!"
  else
    echo "The WebView2installer installer doesn't exist and will be downloaded for you!"
    wget "$SP_WEBVIEW2_INSTALLER_URL" -cO WebView2installer.exe
    mv "WebView2installer.exe" "$SP_PATH/downloads/WebView2installer.exe"
  fi
}

###############################################################################################################################################################
# ALL FUNCTIONS FOR DESKTOP-FILES START HERE:                                                                                                                 #
###############################################################################################################################################################

# Helper function for the following function. The AdskIdentityManager.exe can be installed 
# into a variable alphanumeric folder.
# This function finds that folder alphanumeric folder name.
function SP_DETERMINE_VARIABLE_FOLDER_NAME_FOR_IDENTITY_MANAGER {
  echo "Searching for the variable location of the Fusion 360 identity manager..."
  IDENT_MAN_PATH=$(find "$WP_DIRECTORY" -name 'AdskIdentityManager.exe')
  # Get the dirname of the identity manager's alphanumeric folder.
  # With the full path of the identity manager, go 2 folders up and isolate the folder name.
  IDENT_MAN_VARIABLE_DIRECTORY=$(basename "$(dirname "$(dirname "$IDENT_MAN_PATH")")")
}

# Load the icons and .desktop-files:
function SP_FUSION360_SHORTCUTS_LOAD {
  # Create a .desktop file (launcher.sh) for Autodesk Fusion 360!
  wget -Nc -P "$SP_PATH/graphics" https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/setup/resource/graphics/autodesk_fusion.svg
  rm "$HOME/.local/share/applications/wine/Programs/Autodesk/Autodesk Fusion 360.desktop"
  mkdir -p "$HOME/.local/share/applications/wine/Programs/Autodesk/Fusion360/$WP_TYPE"
  cat >> "$HOME/.local/share/applications/wine/Programs/Autodesk/Fusion360/$WP_TYPE/fusion360.desktop" << EOF
[Desktop Entry]
Name=Autodesk Fusion 360 - $WP_TYPE
GenericName=CAD Application
GenericName[cs]=Aplikace CAD
GenericName[de]=CAD-Anwendung
GenericName[es]=Aplicación CAD
GenericName[fr]=Application CAO
GenericName[it]=Applicazione CAD
GenericName[ja]=CADアプリケーション
GenericName[ko]=CAD 응용
GenericName[zh_CN]=计算机辅助设计应用
Comment=Autodesk Fusion 360 is a cloud-based 3D modeling, CAD, CAM, and PCB software platform for product design and manufacturing.
Comment[cs]=Autodesk Fusion 360 je cloudová platforma pro 3D modelování, CAD, CAM a PCB určená k navrhování a výrobě produktů.
Comment[de]=Autodesk Fusion 360 ist eine cloudbasierte Softwareplattform für Modellierung, CAD, CAM, CAE und Leiterplatten in 3D für Produktdesign und Fertigung.
Comment[es]=Autodesk Fusion 360 es una plataforma de software de modelado 3D, CAD, CAM y PCB basada en la nube destinada al diseño y la fabricación de productos.
Comment[fr]=Autodesk Fusion 360 est une plate-forme logicielle 3D cloud de modélisation, de CAO, de FAO, d’IAO et de conception de circuits imprimés destinée à la conception et à la fabrication de produits.
Comment[it]=Autodesk Fusion 360 è una piattaforma software di modellazione 3D, CAD, CAM, CAE e PCB basata sul cloud per la progettazione e la realizzazione di prodotti.
Comment[ja]=Autodesk Fusion 360は、製品の設計と製造のためのクラウドベースの3Dモデリング、CAD、CAM、およびPCBソフトウェアプラットフォームです。
Comment[ko]=Autodesk Fusion 360은 제품 설계 및 제조를 위한 클라우드 기반 3D 모델링, CAD, CAM 및 PCB 소프트웨어 플랫폼입니다.
Comment[zh_CN]=Autodesk Fusion 360 是一个基于云的 3D 建模、CAD、CAM 和 PCB 软件平台，用于产品设计和制造。
Exec=$WP_DIRECTORY/box-run.sh
Type=Application
Categories=Education;Engineering;
StartupNotify=true
Icon=$SP_PATH/graphics/autodesk_fusion.svg
Terminal=false
Path=$WP_DIRECTORY
EOF

  # Create a .desktop file (uninstall.sh) for Autodesk Fusion 360!
  wget -Nc -P "$SP_PATH/graphics" https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/setup/resource/graphics/autodesk_fusion.svg
  cat >> "$HOME/.local/share/applications/wine/Programs/Autodesk/Fusion360/$WP_TYPE/fusion360uninstall.desktop" << EOF
[Desktop Entry]
Name=Autodesk Fusion 360 (Uninstall) - $WP_TYPE
Name[cs]=Autodesk Fusion 360 (Odinstalovat) - $WP_TYPE
Name[de]=Autodesk Fusion 360 (Deinstallieren) - $WP_TYPE
Name[es]=Autodesk Fusion 360 (Desinstalar) - $WP_TYPE
Name[fr]=Autodesk Fusion 360 (Désinstaller) - $WP_TYPE
Name[it]=Autodesk Fusion 360 (Disinstalla) - $WP_TYPE
Name[ja]=Autodesk Fusion 360 (アンインストール) - $WP_TYPE
Name[ko]=Autodesk Fusion 360 (제거) - $WP_TYPE
Name[zh_CN]=Autodesk Fusion 360 (卸载) - $WP_TYPE
Comment=With this program you can delete Autodesk Fusion 360 on your system!
Comment[cs]=Pomocí tohoto programu můžete odstranit Autodesk Fusion 360 ze svého systému!
Comment[de]=Mit diesem Programm können Sie Autodesk Fusion 360 auf Ihrem System löschen!
Comment[es]=¡Con este programa puede eliminar Autodesk Fusion 360 en su sistema!
Comment[fr]=Avec ce programme, vous pouvez supprimer Autodesk Fusion 360 sur votre système !
Comment[it]=Con questo programma puoi eliminare Autodesk Fusion 360 sul tuo sistema!
Comment[ja]=このプログラムを使用すると、システム上のAutodeskFusion360を削除できます。
Comment[ko]=이 프로그램을 사용하면 시스템에서 Autodesk Fusion 360을 삭제할 수 있습니다!
Comment[zh_CN]=使用此程序，您可以删除系统上的 Autodesk Fusion 360！
Exec=bash ./uninstall.sh
Type=Application
Categories=Education;Engineering;
StartupNotify=true
Icon=$SP_PATH/graphics/autodesk_fusion.svg
Terminal=false
Path=$SP_PATH/bin
EOF

  # Execute function
  SP_DETERMINE_VARIABLE_FOLDER_NAME_FOR_IDENTITY_MANAGER

  #Create mimetype link to handle web login call backs to the Identity Manager
  cat > $HOME/.local/share/applications/adskidmgr-opener.desktop << EOL
[Desktop Entry]
Type=Application
Name=adskidmgr Scheme Handler
Exec=sh -c 'env WINEPREFIX="$WP_DIRECTORY" wine "$(find $WP_DIRECTORY/ -name "AdskIdentityManager.exe" | head -1 | xargs -I '{}' echo {})" "%u"'
StartupNotify=false
MimeType=x-scheme-handler/adskidmgr;
EOL
xdg-mime default adskidmgr-opener.desktop x-scheme-handler/adskidmgr

  #Disable Debug messages on regular runs, we dont have a terminal, so speed up the system by not wasting time prining them into the Void
  sed -i 's/=env WINEPREFIX=/=env WINEDEBUG=-all env WINEPREFIX=/g' "$HOME/.local/share/applications/wine/Programs/Autodesk/Fusion360/$WP_TYPE/fusion360.desktop"

  # Create a link to the Wineprefixes Box:
  cat >> "$WP_DIRECTORY/box-run.sh" << EOF
#!/usr/bin/env bash
WP_BOX='$WP_DIRECTORY' source $SP_PATH/bin/launcher.sh
EOF
  chmod +x "$WP_DIRECTORY/box-run.sh"

  # Download some script files for Autodesk Fusion 360!
  wget -NP "$SP_PATH/bin" https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/builds/stable-branch/bin/uninstall.sh
  chmod +x "$SP_PATH/bin/uninstall.sh"
  wget -NP "$SP_PATH/bin" https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/builds/stable-branch/bin/launcher.sh
  chmod +x "$SP_PATH/bin/launcher.sh"
  wget -NP "$SP_PATH/bin" https://raw.githubusercontent.com/cryinkfly/Autodesk-Fusion-360-for-Linux/main/files/builds/stable-branch/bin/update.sh
  chmod +x "$SP_PATH/bin/update.sh"
}

###############################################################################################################################################################
# ALL FUNCTIONS FOR DXVK AND OPENGL START HERE:                                                                                                               #
###############################################################################################################################################################

function SP_DXVK_OPENGL_1 {
  if [[ $WP_DRIVER = "DXVK" ]]; then
    WINEPREFIX=$WP_DIRECTORY sh "$SP_PATH/bin/winetricks" -q dxvk
    wget -Nc -P "$WP_DIRECTORY/drive_c/users/$USER/Downloads" https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/setup/resource/video_driver/dxvk/DXVK.reg
    # Add the "return"-option. Here you can read more about it -> https://github.com/koalaman/shellcheck/issues/592
    cd "$WP_DIRECTORY/drive_c/users/$USER/Downloads" || return
    WINEPREFIX=$WP_DIRECTORY wine regedit.exe DXVK.reg
  fi
}

function SP_DXVK_OPENGL_2 {
  if [[ $WP_DRIVER = "DXVK" ]]; then
    wget -N https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/setup/resource/video_driver/dxvk/NMachineSpecificOptions.xml
  else
    wget -N https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/setup/resource/video_driver/opengl/NMachineSpecificOptions.xml
  fi
}

###############################################################################################################################################################

function SP_DRIVER_SETTINGS {
WP_DRIVER=$(awk 'NR == 2' /tmp/fusion360/settings.txt)
}

###############################################################################################################################################################
# ALL FUNCTIONS FOR WINE AND WINETRICKS START HERE:                                                                                                           #
###############################################################################################################################################################

# Start Fusion360installer.exe - Part 1
function SP_FUSION360_INSTALL_DEFAULT_1 {
  WINEPREFIX="$WP_DIRECTORY" timeout -k 10m 9m wine "$WP_DIRECTORY/drive_c/users/$USER/Downloads/Fusion360installer.exe" --quiet
}

# Start Fusion360installer.exe - Part 2
function SP_FUSION360_INSTALL_DEFAULT_2 {
  WINEPREFIX="$WP_DIRECTORY" timeout -k 5m 4m wine "$WP_DIRECTORY/drive_c/users/$USER/Downloads/Fusion360installer.exe" --quiet
}

###############################################################################################################################################################

# Start Fusion360installer.exe - Part 1 (Refresh)
function SP_FUSION360_INSTALL_REFRESH_1 {
  WINEPREFIX="$WP_WINEPREFIXES_REFRESH" timeout -k 10m 9m wine "$WP_WINEPREFIXES_REFRESH/drive_c/users/$USER/Downloads/Fusion360installer.exe" --quiet
}

# Start Fusion360installer.exe - Part 2 (Refresh)
function SP_FUSION360_INSTALL_REFRESH_2 {
  WINEPREFIX="$WP_WINEPREFIXES_REFRESH" timeout -k 5m 4m wine "$WP_WINEPREFIXES_REFRESH/drive_c/users/$USER/Downloads/Fusion360installer.exe" --quiet
}

###############################################################################################################################################################

# Autodesk Fusion 360 will now be installed using Wine and Winetricks.
function SP_FUSION360_INSTALL {
  SP_WINETRICKS_LOAD
  SP_FUSION360_INSTALLER_LOAD
  SP_WEBVIEW2_INSTALLER_LOAD
  # Note that the winetricks sandbox verb merely removes the desktop integration and Z: drive symlinks and is not a "true" sandbox.
  # It protects against errors rather than malice. It's useful for, e.g., keeping games from saving their settings in random subdirectories of your home directory.
  # But it still ensures that wine, for example, no longer has access permissions to Home!
  # For this reason, the EXE files must be located directly in the Wineprefix folder!
  mkdir -p "$WP_DIRECTORY"
  cd "$WP_DIRECTORY" || return
  WINEPREFIX="$WP_DIRECTORY" sh "$SP_PATH/bin/winetricks" -q sandbox
  sleep 5s
  WINEPREFIX="$WP_DIRECTORY" sh "$SP_PATH/bin/winetricks" -q sandbox
  sleep 5s
  # We must install some packages!
  WINEPREFIX="$WP_DIRECTORY" sh "$SP_PATH/bin/winetricks" -q atmlib gdiplus arial corefonts cjkfonts dotnet452 msxml4 msxml6 vcrun2017 fontsmooth=rgb winhttp win10
  sleep 5s
  # We must install cjkfonts again then sometimes it doesn't work in the first time!
  WINEPREFIX="$WP_DIRECTORY" sh "$SP_PATH/bin/winetricks" -q cjkfonts
  sleep 5s
  SP_DXVK_OPENGL_1
  # We must set to Windows 10 again because some other winetricks sometimes set it back to Windows XP!
  WINEPREFIX="$WP_DIRECTORY" sh "$SP_PATH/bin/winetricks" -q win10
  sleep 5s
  #Remove tracking metrics/calling home
  WINEPREFIX="$WP_DIRECTORY" wine REG ADD "HKCU\Software\Wine\DllOverrides" /v "adpclientservice.exe" /t REG_SZ /d "" /f
  #Navigation bar does not work well with anything other than the wine builtin DX9
  WINEPREFIX="$WP_DIRECTORY" wine REG ADD "HKCU\Software\Wine\DllOverrides" /v "AdCefWebBrowser.exe" /t REG_SZ /d builtin /f
  #Use Visual Studio Redist that is bundled with the application
  WINEPREFIX="$WP_DIRECTORY" wine REG ADD "HKCU\Software\Wine\DllOverrides" /v "msvcp140" /t REG_SZ /d native /f
  WINEPREFIX="$WP_DIRECTORY" wine REG ADD "HKCU\Software\Wine\DllOverrides" /v "mfc140u" /t REG_SZ /d native /f
  # Fixed the problem with the bcp47langs issue and now the login works again!
  WINEPREFIX="$WP_DIRECTORY" wine reg add "HKCU\Software\Wine\DllOverrides" /v "bcp47langs" /t REG_SZ /d "" /f
  sleep 5s
  #Download and install WebView2 to handle Login attempts, required even though we redirect to your default browser
  cp "$SP_PATH/downloads/WebView2installer.exe" "$WP_DIRECTORY/drive_c/users/$USER/Downloads"
  WINEPREFIX="$WP_DIRECTORY" wine "$WP_DIRECTORY/drive_c/users/$USER/Downloads/WebView2installer.exe" /install #/silent
  sleep 5s
  # Pre-create shortcut directory for latest re-branding
  mkdir -p "$WP_DIRECTORY/drive_c/users/$USER/AppData/Roaming/Microsoft/Internet Explorer/Quick Launch/User Pinned/"
  # We must copy the EXE-file directly in the Wineprefix folder (Sandbox-Mode)!
  cp "$SP_PATH/downloads/Fusion360installer.exe" "$WP_DIRECTORY/drive_c/users/$USER/Downloads"
  # This start and stop the installer automatically after a time!
  # For more information check this link: https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/issues/232
  SP_FUSION360_INSTALL_PROGRESS
  mkdir -p "$WP_DIRECTORY/drive_c/users/$USER/AppData/Roaming/Autodesk/Neutron Platform/Options"
  cd "$WP_DIRECTORY/drive_c/users/$USER/AppData/Roaming/Autodesk/Neutron Platform/Options" || return
  SP_DXVK_OPENGL_2
  mkdir -p "$WP_DIRECTORY/drive_c/users/$USER/AppData/Local/Autodesk/Neutron Platform/Options"
  cd "$WP_DIRECTORY/drive_c/users/$USER/AppData/Local/Autodesk/Neutron Platform/Options" || return
  SP_DXVK_OPENGL_2
  mkdir -p "$WP_DIRECTORY/drive_c/users/$USER/Application Data/Autodesk/Neutron Platform/Options"
  cd "$WP_DIRECTORY/drive_c/users/$USER/Application Data/Autodesk/Neutron Platform/Options" || return
  SP_DXVK_OPENGL_2
  cd "$SP_PATH/bin" || return
  SP_GET_WINEPREFIX_TYPE
  SP_FUSION360_SHORTCUTS_LOAD
  SP_FUSION360_EXTENSIONS
  SP_LOGFILE_WINEPREFIX
  SP_COMPLETED
}

function SP_FUSION360_REFRESH {
  wget "$SP_FUSION360_INSTALLER_URL" -cO Fusion360installer.exe
  mv "Fusion360installer.exe" "$SP_PATH/downloads/Fusion360installer.exe"
  rmdir "$WP_WINEPREFIXES_REFRESH/drive_c/users/$USER/Downloads/Fusion360installer.exe"
  cp "$SP_PATH/downloads/Fusion360installer.exe" "$WP_WINEPREFIXES_REFRESH/drive_c/users/$USER/Downloads"
  SP_FUSION360_INSTALL_PROGRESS_REFRESH
}

###############################################################################################################################################################
# ALL FUNCTIONS FOR SUPPORTED LINUX DISTRIBUTIONS START HERE:                                                                                                 #
###############################################################################################################################################################

function OS_ARCHLINUX {
  echo "Checking for multilib..."
  if ARCHLINUX_VERIFY_MULTILIB ; then
    echo "multilib found. Continuing..."
    pkexec sudo pacman -Syu --needed wine wine-mono wine_gecko winetricks p7zip curl cabextract samba ppp
    SP_FUSION360_INSTALL
  else
    echo "Enabling multilib..."
    echo "[multilib]" | sudo tee -a /etc/pacman.conf
    echo "Include = /etc/pacman.d/mirrorlist" | sudo tee -a /etc/pacman.conf
    pkexec sudo pacman -Syu --needed wine wine-mono wine_gecko winetricks p7zip curl cabextract samba ppp
    SP_FUSION360_INSTALL
  fi
}

function ARCHLINUX_VERIFY_MULTILIB {
  if grep -q '^\[multilib\]$' /etc/pacman.conf ; then
    true
  else
    false
  fi
}

###############################################################################################################################################################

function DEBIAN_BASED_1 {
  # Some systems require this command for all repositories to work properly and for the packages to be downloaded for installation!
  pkexec sudo apt-get --allow-releaseinfo-change update
  # Added i386 support for wine!
  sudo dpkg --add-architecture i386
}

function DEBIAN_BASED_2 {
  sudo apt-get update
  sudo apt-get install -y p7zip p7zip-full p7zip-rar curl winbind cabextract wget
  sudo apt-get install -y --install-recommends winehq-staging
  SP_FUSION360_INSTALL
}

function OS_DEBIAN_11 {
  sudo apt-add-repository -r 'deb https://dl.winehq.org/wine-builds/debian/ bullseye main'
  wget -q https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_11/Release.key -O Release.key -O- | sudo apt-key add -
  sudo apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_11/ ./'
}

function OS_DEBIAN_12 {
  sudo apt-add-repository -r 'deb https://dl.winehq.org/wine-builds/debian/ bookworm main'
  wget -q https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_12/Release.key -O Release.key -O- | sudo apt-key add -
  sudo apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_12/ ./'
}

function OS_DEBIAN_TESTING {
  sudo apt-add-repository -r 'deb https://dl.winehq.org/wine-builds/debian/ testing main'
  wget -q https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_Testing_standard//Release.key -O Release.key -O- | sudo apt-key add -
  sudo apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_Testing_standard/ ./'
}

function OS_UBUNTU_20 {
  sudo add-apt-repository -r 'deb https://dl.winehq.org/wine-builds/ubuntu/ focal main'
  wget -q https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_20.04/Release.key -O Release.key -O- | sudo apt-key add -
  sudo apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_20.04/ ./'
}

function OS_UBUNTU_22 {
  sudo add-apt-repository -r 'deb https://dl.winehq.org/wine-builds/ubuntu/ jammy main'
  wget -q https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_22.04/Release.key -O Release.key -O- | sudo apt-key add -
  sudo apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_22.04/ ./'
}

function OS_UBUNTU_23 {
  sudo add-apt-repository -r 'deb https://dl.winehq.org/wine-builds/ubuntu/ lunar main'
  wget -q https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_23.10/Release.key -O Release.key -O- | sudo apt-key add -
  sudo apt-add-repository 'deb https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/xUbuntu_23.10/ ./'
}

###############################################################################################################################################################

function FEDORA_BASED_1 {
  pkexec sudo dnf update
  sudo dnf upgrade
  sudo dnf install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
}

function FEDORA_BASED_2 {
  sudo dnf install p7zip p7zip-plugins curl wget wine cabextract
  SP_FUSION360_INSTALL
}

function OS_FEDORA_38 {
  sudo dnf config-manager --add-repo https://download.opensuse.org/repositories/Emulators:/Wine:/Fedora/Fedora_38/Emulators:Wine:Fedora.repo
}

function OS_FEDORA_39 {
  sudo dnf config-manager --add-repo https://download.opensuse.org/repositories/Emulators:/Wine:/Fedora/Fedora_39/Emulators:Wine:Fedora.repo
}

function OS_FEDORA_RAWHIDE {
  sudo dnf config-manager --add-repo https://download.opensuse.org/repositories/Emulators:/Wine:/Fedora/Fedora_Rawhide/Emulators:Wine:Fedora.repo
}

###############################################################################################################################################################

function OS_OPENSUSE_154 {
  pkexec su -c 'zypper up && zypper rr https://download.opensuse.org/repositories/Emulators:/Wine/15.4/ wine && zypper ar -cfp 95 https://download.opensuse.org/repositories/Emulators:/Wine/15.4/ wine && zypper install p7zip-full curl wget wine cabextract'
  SP_FUSION360_INSTALL
}

# Has not been published yet!
function OS_OPENSUSE_155 {
  pkexec su -c 'zypper up && zypper rr https://download.opensuse.org/repositories/Emulators:/Wine/15.5/ wine && zypper ar -cfp 95 https://download.opensuse.org/repositories/Emulators:/Wine/15.5/ wine && zypper install p7zip-full curl wget wine cabextract'
  SP_FUSION360_INSTALL
}

function OS_OPENSUSE_TW {
  pkexec su -c 'zypper up && zypper rr https://download.opensuse.org/repositories/Emulators:/Wine/openSUSE_Tumbleweed/ wine && zypper ar -cfp 95 https://download.opensuse.org/repositories/Emulators:/Wine/openSUSE_Tumbleweed/ wine && zypper install p7zip-full curl wget wine cabextract'
  SP_FUSION360_INSTALL
}

###############################################################################################################################################################

function OS_REDHAT_LINUX_8 {
  pkexec sudo subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms
  sudo rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
  sudo dnf upgrade
  sudo dnf install wine
  SP_FUSION360_INSTALL
}

function OS_REDHAT_LINUX_9 {
  pkexec sudo subscription-manager repos --enable codeready-builder-for-rhel-9-x86_64-rpms
  sudo rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  sudo dnf upgrade
  sudo dnf install wine
  SP_FUSION360_INSTALL
}

###############################################################################################################################################################

function OS_SOLUS_LINUX {
  pkexec sudo eopkg install -y wine winetricks p7zip curl cabextract samba ppp
  SP_FUSION360_INSTALL
}

###############################################################################################################################################################

function OS_VOID_LINUX {
  pkexec sudo xbps-install -Sy wine wine-mono wine-gecko winetricks p7zip curl cabextract samba ppp
  SP_FUSION360_INSTALL
}

###############################################################################################################################################################

function OS_GENTOO_LINUX {
  pkexec sudo emerge -nav virtual/wine app-emulation/winetricks app-emulation/wine-mono app-emulation/wine-gecko app-arch/p7zip app-arch/cabextract net-misc/curl net-fs/samba net-dialup/ppp
  SP_FUSION360_INSTALL
}

###############################################################################################################################################################
# ALL FUNCTIONS FOR THE EXTENSIONS START HERE:                                                                                                                #
###############################################################################################################################################################

# Install a extension: Czech localization for F360
function EXTENSION_CZECH_LOCALE {
  cd "$SP_PATH/extensions" || return
  wget -Nc https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/extensions/Ceska_lokalizace_pro_Autodesk_Fusion.exe &&
  cp "Ceska_lokalizace_pro_Autodesk_Fusion.exe" "$WP_DIRECTORY/drive_c/users/$USER/Downloads"
  cd "$WP_DIRECTORY/drive_c/users/$USER/Downloads" || return
  WINEPREFIX="$WP_DIRECTORY" wine Ceska_lokalizace_pro_Autodesk_Fusion.exe
}

###############################################################################################################################################################

# Install a extension: HP 3D Printers for Autodesk® Fusion 360™
function EXTENSION_HP_3DPRINTER_CONNECTOR {
  cd "$SP_PATH/extensions" || return
  wget -Nc https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/extensions/HP_3DPrinters_for_Fusion360-win64.msi &&
  cp HP_3DPrinters_for_Fusion360-win64.msi "$WP_DIRECTORY/drive_c/users/$USER/Downloads"
  cd "$WP_DIRECTORY/drive_c/users/$USER/Downloads" || return
  WINEPREFIX="$WP_DIRECTORY" wine msiexec /i HP_3DPrinters_for_Fusion360-win64.msi
}

###############################################################################################################################################################

# Install a extension: OctoPrint for Autodesk® Fusion 360™
function EXTENSION_OCTOPRINT {
  cd "$SP_PATH/extensions" || return
  wget -Nc https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/extensions/OctoPrint_for_Fusion360-win64.msi &&
  cp OctoPrint_for_Fusion360-win64.msi "$WP_DIRECTORY/drive_c/users/$USER/Downloads"
  cd "$WP_DIRECTORY/drive_c/users/$USER/Downloads" || return
  WINEPREFIX="$WP_DIRECTORY" wine msiexec /i OctoPrint_for_Fusion360-win64.msi
}

###############################################################################################################################################################


###############################################################################################################################################################

# Install a extension: Ultimaker Digital Factory for Autodesk Fusion 360™
function EXTENSION_ULTIMAKER_DIGITAL_FACTORY {
  cd "$SP_PATH/extensions" || return
  wget -Nc https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux/raw/main/files/extensions/Ultimaker_Digital_Factory-win64.msi &&
  cp Ultimaker_Digital_Factory-win64.msi "$WP_DIRECTORY/drive_c/users/$USER/Downloads"
  cd "$WP_DIRECTORY/drive_c/users/$USER/Downloads" || return
  WINEPREFIX="$WP_DIRECTORY" wine msiexec /i Ultimaker_Digital_Factory-win64.msi
}

###############################################################################################################################################################
# ALL DIALOGS ARE ARRANGED HERE:                                                                                                                              #
###############################################################################################################################################################

function SP_WELCOME {
yad \
--form \
--separator="" \
--center \
--height=125 \
--width=750 \
--buttons-layout=center \
--title="$SP_TITLE" \
--field="<big>$SP_SUBTITLE</big>:LBL" \
--field="$SP_WELCOME_LABEL_1:LBL" \
--field="$SP_WELCOME_LABEL_2:LBL" \
--align=center \
--button=gtk-about!!"$SP_WELCOME_TOOLTIP_1":1 \
--button=gtk-preferences!!"$SP_WELCOME_TOOLTIP_2":2 \
--button=gtk-cancel:99 \
--button=gtk-ok:3

ret=$?

# Responses to above button presses are below:
case $ret in
  1)
    xdg-open https://github.com/cryinkfly/Autodesk-Fusion-360-for-Linux
    SP_WELCOME
    ;;
  2)
    SP_SETTINGS
    SP_LOCALE_SETTINGS
    SP_DRIVER_SETTINGS
    SP_WELCOME
    ;;
  3)
    SP_LICENSE
    ;;
esac
}

###############################################################################################################################################################

function SP_SETTINGS {
yad --title="$SP_TITLE" \
--form --separator="," --item-separator="," \
--borders=15 \
--width=550 \
--buttons-layout=center \
--align=center \
--field="<big><b>$SP_SETTINGS_TITLE</b></big>:LBL" \
--field=":LBL" \
--field="$SP_SETTINGS_LABEL_1:LBL" \
--field="$SP_LOCALE_LABEL:CB" \
--field="$WP_DRIVER_LABEL:CB" \
--field="$SP_SETTINGS_LABEL_2:LBL" \
"" "" "" "$SP_LOCALE_SELECT" "$WP_DRIVER_SELECT" "" | while read line; do
echo "$line" | awk -F',' '{print $4}' > /tmp/fusion360/settings.txt
echo "$line" | awk -F',' '{print $5}' >> /tmp/fusion360/settings.txt
cp "/tmp/fusion360/settings.txt" "$SP_PATH/config"
done
}

###############################################################################################################################################################

function SP_LICENSE {
SP_LICENSE_TEXT=$(cat "$SP_LICENSE")
SP_LICENSE_CHECK=$(yad \
--title="$SP_TITLE" \
--form \
--borders=15 \
--width=550 \
--height=450 \
--buttons-layout=center \
--align=center \
--field=":TXT" "$SP_LICENSE_TEXT" \
--field="$SP_LICENSE_CHECK_LABEL:CHK" )

if [[ $SP_LICENSE_CHECK = *"TRUE"* ]]; then
    echo "TRUE"
    SP_LOGFILE_WINEPREFIX_CHECK
else
    echo "FALSE"
    SP_WELCOME
fi
}

###############################################################################################################################################################

function SP_LOGFILE_WINEPREFIX_INFO {
yad \
--form \
--separator="" \
--center \
--height=125 \
--width=750 \
--buttons-layout=center \
--title="$SP_TITLE" \
--field="<big>$SP_LOGFILE_WINEPREFIX_INFO_TITLE</big>:LBL" \
--field="$SP_LOGFILE_WINEPREFIX_INFO_LABEL_1:LBL" \
--field="$SP_LOGFILE_WINEPREFIX_INFO_LABEL_2:LBL" \
--align=center \
--button=gtk-new!!"$SP_LOGFILE_WINEPREFIX_INFO_TOOLTIP_1":1 \
--button=gtk-refresh!!"$SP_LOGFILE_WINEPREFIX_INFO_TOOLTIP_2":2 \
--button=gtk-delete!!"$SP_LOGFILE_WINEPREFIX_INFO_TOOLTIP_3":3 \
--button=gtk-cancel:99

ret=$?

# Responses to above button presses are below:
case $ret in
  1)
    SP_INSTALLDIR
    ;;
  2)
    # Get informations about the current wineprefix - Repair
    WP_WINEPREFIXES_STRING=$(yad --height=300 --separator="|" --list --radiolist --column="$SELECT" --column="$WINEPREFIXES_TYPE" --column="$WINEPREFIXES_DRIVER" --column="$WINEPREFIXES_DIRECTORY" < /tmp/fusion360/logs/wineprefixes.log)
    WP_WINEPREFIXES_REFRESH=$(echo "$WP_WINEPREFIXES_STRING" | awk -F'|' '{print $4}')
    SP_FUSION360_REFRESH
    ;;
  3)
    # Get informations about the current wineprefix - Delete
    # shellcheck source=./uninstall.sh
    source "$SP_PATH/bin/uninstall.sh"
    ;;
esac
}

###############################################################################################################################################################

function SP_INSTALLDIR {
WP_DIRECTORY=$(yad --title="$SP_TITLE" \
--form --separator="" \
--borders=15 \
--width=550 \
--buttons-layout=center \
--align=center \
--field="<big><b>$SP_INSTALLDIR_TITLE</b></big>:LBL" \
--field=":LBL" \
--field="<b>$SP_INSTALLDIR_LABEL_1</b>:LBL" \
--field="$SP_INSTALLDIR_LABEL_2:DIR" \
--field="<b>$SP_INSTALLDIR_LABEL_3</b>:LBL" \
"" "" "" "$SP_PATH/wineprefixes/default" "" )

# Continue with the installation ...
SP_INSTALLDIR_CHECK
}

###############################################################################################################################################################

function SP_INSTALLDIR_INFO {
yad \
--form \
--separator="" \
--center \
--height=125 \
--width=750 \
--buttons-layout=center \
--title="$SP_TITLE" \
--field="<big>$SP_INSTALLDIR_INFO_TITLE</big>:LBL" \
--field="$SP_INSTALLDIR_INFO_LABEL_1:LBL" \
--field="$SP_INSTALLDIR_INFO_LABEL_2:LBL" \
--align=center \
--button=gtk-cancel:99 \
--button=gtk-ok:1

ret=$?

# Responses to above button presses are below:
if [[ $ret -eq 1 ]]; then
    SP_INSTALLDIR
fi
}

###############################################################################################################################################################

function SP_WINE_SETTINGS {
WINE_VERSION=$(yad --title="$SP_TITLE" \
--form --separator="" --item-separator="," \
--borders=15 \
--width=550 \
--buttons-layout=center \
--align=center \
--field="<big><b>$SP_WINE_SETTINGS_TITLE</b></big>:LBL" \
--field=":LBL" \
--field="<b>$SP_WINE_SETTINGS_LABEL_1</b>:LBL" \
--field="$SP_WINE_SETTINGS_LABEL_2:CB" \
--field="<b>$SP_WINE_SETTINGS_LABEL_3</b>:LBL" \
"" "" "" "$SP_WINE_VERSION_SELECT" "" )


case "$WINE_VERSION" in
  # Czech:
  "Verze vína (Staging)")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # German:
  "Wine Version (Entwicklungsversion)")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # English:
  "Wine Version (Staging)")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # Spanish:
  "Versión Vino (Puesta en Escena)")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # French:
  "Version Vin (Mise en scène)")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # Italian
  "Versione vino (messa in scena)")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # Japanese:
  "ワインバージョン（ステージング）")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # Korean:
  "와인 버전(스테이징)")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  # Chinese:
  "葡萄酒版（分期）")
    echo "Install Wine on your system!"
    SP_OS_SETTINGS
    ;;
  *)
    echo "Wine version (8.14 or higher) is already installed on the system!"
    # Check the correct Wine Version before continuing!
    SP_CHECK_WINE_VERSION
    ;;
esac
}

###############################################################################################################################################################

function SP_OS_SETTINGS {
SP_OS=$(yad --title="$SP_TITLE" \
--form --separator="" --item-separator="," \
--borders=15 \
--width=550 \
--buttons-layout=center \
--align=center \
--field="<big><b>$SP_OS_TITLE</b></big>:LBL" \
--field=":LBL" \
--field="$SP_OS_LABEL_1:LBL" \
--field="$SP_OS_LABEL_2:CB" \
"" "" "" "$SP_OS_SELECT" )

case "$SP_OS" in
  "Arch Linux")
    echo "Arch Linux"
    OS_ARCHLINUX
    ;;
  "Debian 11")
    echo "Debian 11"
    DEBIAN_BASED_1
    OS_DEBIAN_11
    DEBIAN_BASED_2
    ;;
  "Debian 12")
    echo "Debian 12"
    DEBIAN_BASED_1
    OS_DEBIAN_12
    DEBIAN_BASED_2
    ;;
  "Debian Testing")
    echo "Debian Testing"
    DEBIAN_BASED_1
    OS_DEBIAN_TESTING
    DEBIAN_BASED_2
    ;;
  "EndeavourOS")
    echo "EndeavourOS"
    OS_ARCHLINUX
    ;;
  "Fedora 38")
    echo "Fedora 38"
    FEDORA_BASED_1
    OS_FEDORA_37
    FEDORA_BASED_2
    ;;
  "Fedora 39")
    echo "Fedora 39"
    FEDORA_BASED_1
    OS_FEDORA_38
    FEDORA_BASED_2
    ;;
  "Fedora Rawhide")
    echo "Fedora Rawhide"
    FEDORA_BASED_1
    OS_FEDORA_RAWHIDE
    FEDORA_BASED_2
    ;;
  "Linux Mint 20.x")
    echo "Linux Mint 20.x"
    DEBIAN_BASED_1
    OS_UBUNTU_20
    DEBIAN_BASED_2
    ;;
  "Linux Mint 21.x")
    echo "Linux Mint 21.x"
    DEBIAN_BASED_1
    OS_UBUNTU_23
    DEBIAN_BASED_2
    ;;
  "Linux Mint 5.x - LMDE Version")
    echo "Linux Mint 5.x - LMDE Version"
    DEBIAN_BASED_1
    OS_DEBIAN_11
    DEBIAN_BASED_2
    ;;
  "Manjaro Linux")
    echo "Manjaro Linux"
    OS_ARCHLINUX
    ;;
  "openSUSE Leap 15.4")
    echo "openSUSE Leap 15.4"
    OS_OPENSUSE_154
    ;;
  "openSUSE Leap 15.5")
    echo "openSUSE Leap 15.5"
    OS_OPENSUSE_155
    ;;
  "openSUSE Tumbleweed")
    echo "openSUSE Tumbleweed"
    OS_OPENSUSE_TW
    ;;
  "Red Hat Enterprise Linux 8.x")
    echo "Red Hat Enterprise Linux 8.x"
    OS_REDHAT_LINUX_8
    ;;
  "Red Hat Enterprise Linux 9.x")
    echo "Red Hat Enterprise Linux 9.x"
    OS_REDHAT_LINUX_9
    ;;
  "Solus")
    echo "Solus"
    OS_SOLUS_LINUX
    ;;
  "Ubuntu 18.04")
    echo "Ubuntu 18.04"
    DEBIAN_BASED_1
    OS_UBUNTU_18
    DEBIAN_BASED_2
    ;;
  "Ubuntu 20.04")
    echo "Ubuntu 20.04"
    DEBIAN_BASED_1
    OS_UBUNTU_20
    DEBIAN_BASED_2
    ;;
  "Ubuntu 22.04")
    echo "Ubuntu 22.04"
    DEBIAN_BASED_1
    OS_UBUNTU_22
    DEBIAN_BASED_2
    ;;
  "Ubuntu 23.10")
    echo "Ubuntu 23.10"
    DEBIAN_BASED_1
    OS_UBUNTU_23
    DEBIAN_BASED_2
    ;;
  "Void Linux")
    echo "Void Linux"
    OS_VOID_LINUX
    ;;
  "Gentoo Linux")
    echo "Gentoo Linux"
    OS_GENTOO_LINUX
    ;;
esac
}

###############################################################################################################################################################

function SP_FUSION360_INSTALL_PROGRESS {

SP_FUSION360_INSTALL_PROGRESS_MAIN () {
cd "$WP_DIRECTORY" || return
echo "20"
SP_FUSION360_INSTALL_DEFAULT_1
echo "70"
SP_FUSION360_INSTALL_DEFAULT_2
sleep 5
echo "100"
}

SP_FUSION360_INSTALL_PROGRESS_MAIN | yad --progress --progress-text "$SP_INSTALL_PROGRESS_LABEL" --percentage=0 --auto-close
}

###############################################################################################################################################################

function SP_FUSION360_INSTALL_PROGRESS_REFRESH {

SP_FUSION360_INSTALL_PROGRESS_MAIN_REFRESH () {
cd "$WP_DIRECTORY" || return
echo "20"
SP_FUSION360_INSTALL_REFRESH_1
echo "70"
SP_FUSION360_INSTALL_REFRESH_2
sleep 5
echo "100"
}

SP_FUSION360_INSTALL_PROGRESS_MAIN_REFRESH | yad --title="$SP_TITLE" --borders=15 --progress --progress-text "$SP_INSTALL_PROGRESS_REFRESH_LABEL" --percentage=0 --auto-close
}

###############################################################################################################################################################

function SP_FUSION360_EXTENSIONS {
EXTENSIONS=$(yad --title="$SP_TITLE" --borders=15 --button=gtk-cancel:99 --button=gtk-ok:0 --height=300 --list --multiple --checklist --column="$SP_EXTENSION_SELECT" --column="$SP_EXTENSION_NAME" --column="$SP_EXTENSION_DESCRIPTION" < "$SP_EXTENSION_LIST")

if [[ $EXTENSIONS = *"Czech localization for F360"* ]]; then
    echo "Czech localization for F360"
    EXTENSION_CZECH_LOCALE
fi

if [[ $EXTENSIONS = *"HP 3D Printers for Autodesk® Fusion 360™"* ]]; then
    echo "HP 3D Printers for Autodesk® Fusion 360™"
    EXTENSION_HP_3DPRINTER_CONNECTOR
fi

if [[ $EXTENSIONS = *"OctoPrint for Autodesk® Fusion 360™"* ]]; then
    echo "OctoPrint for Autodesk® Fusion 360™"
    EXTENSION_OCTOPRINT
fi

if [[ $EXTENSIONS = *"Ultimaker Digital Factory for Autodesk Fusion 360™"* ]]; then
    echo "Ultimaker Digital Factory for Autodesk Fusion 360™"
    EXTENSION_ULTIMAKER_DIGITAL_FACTORY
fi
}

###############################################################################################################################################################

# The installation is complete and will be terminated.
function SP_COMPLETED {
  echo "The installation is completed!"
  SP_COMPLETED_CHECK=$(yad \
  --title="$SP_TITLE" \
  --form \
  --borders=15 \
  --width=550 \
  --height=450 \
  --buttons-layout=center \
  --align=center \
  --field=":TXT" "$SP_COMPLETED_TEXT" \
  --field="$SP_COMPLETED_CHECK_LABEL:CHK" )

  if [[ $SP_COMPLETED_CHECK = *"TRUE"* ]]; then
    echo "TRUE"
    # shellcheck source=/dev/null
    source "$WP_DIRECTORY/box-run.sh"
  else
    echo "FALSE"
  fi
}

###############################################################################################################################################################
# THE INSTALLATION PROGRAM IS STARTED HERE:                                                                                                                   #
###############################################################################################################################################################

SP_CHECK_REQUIRED_COMMANDS
SP_STRUCTURE
SP_LOGFILE_INSTALL
SP_LOCALE_INDEX
SP_WELCOME
