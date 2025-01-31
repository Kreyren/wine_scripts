#!/bin/bash

### Wine Portable start script
### Version 1.2.2
### Author: Kron
### Contributor: Kreyren! <github.com/kreyren>
### Email: kron4ek@gmail.com
### Link to latest version:
###		Yandex.Disk: https://yadi.sk/d/IrofgqFSqHsPu
###		Google.Drive: https://drive.google.com/open?id=1fTfJQhQSzlEkY-j3g0H6p4lwmQayUNSR
###		Github: https://github.com/Kron4ek/wine_scripts

#### Script for creating portable Wine applications. It works in all Linux
#### distributions that have bash shell and standard GNU utilities.

# Error handling
info() { printf "INFO: $*\n" 1>&2 ; }
warn() { printf "WARN: $*\n" 1>&2 ; }
die() { printf "FATAL: $*\n" 1>&2 ; exit 1 ; }

## Exit if root
[[ "$EUID" == "0" ]] && die "Do not run this script as root!"

## Show help

if [ "$1" == "--help" ]; then
	clear
	printf '%s\n' \
    'Available arguments:' \
    '--debug\t\t\t\tenable Debug mode to see more information' \
	  '\t\t\t\tin output when the game starts.' \
	exit
fi

### Set variables

## Script directory

export SCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
export DIR="$(dirname "$SCRIPT")"

## Wine executables

WINE="$DIR/wine/bin/wine"
WINE64="$DIR/wine/bin/wine64"
WINESERVER="$DIR/wine/bin/wineserver"

## Wine variables

export WINEPREFIX="$DIR/prefix"
export WINEDEBUG="-all"
export WINEDLLOVERRIDES="winemenubuilder.exe="

# Enable WINEDEBUG if --debug argument is passed to script
if [ "$1" = "--debug" ]; then export WINEDEBUG="err+all,fixme-all"; fi

## Other variables

export XDG_CACHE_HOME="$DIR/cache"
export DXVK_LOG_PATH="$DIR/cache/dxvk"
export DXVK_STATE_CACHE_PATH="$DIR/cache/dxvk"

USERNAME="$(id -un)"

## Script variables

# Get settings (variables) from settings file if exists
SCRIPT_NAME="$(basename "$SCRIPT" | cut -d. -f1)"
source "$DIR/settings_$SCRIPT_NAME" &>/dev/null

# Generate settings file if it's not exists or incomplete
if [ -z $CSMT_DISABLE ] || [ -z $DXVK ] || [ -z $USE_PULSEAUDIO ] || [ -z $PBA ] || [ -z $GLIBC_REQUIRED ]; then
  printf '%s\n' \
    'CSMT_DISABLE=0' \
    'USE_PULSEAUDIO=0' \
    'USE_SYSTEM_WINE=0' \
    'RESTORE_RESOLUTION=1' \
    'VIRTUAL_DESKTOP=0' \
    'VIRTUAL_DESKTOP_SIZE=800x600' \
    '' \
    'DXVK=1' \
    'DXVK_HUD=0' \
    'ESYNC=1' \
    'PBA=0' \
    '' \
    'WINDOWS_VERSION=win7' \
    'PREFIX_ARCH=win64' \
    '# Change these GLIBC variables only if you know what you are doing' \
    '' \
    'CHECK_GLIBC=1' \
    'GLIBC_REQUIRED=2.23' \
    '' \
    '# You can also put custom variables in this file' \
  >> "$DIR/settings_$SCRIPT_NAME"

	source "$DIR/settings_$SCRIPT_NAME"
fi

export DXVK_HUD
export WINEESYNC=$ESYNC
export PBA_ENABLE=$PBA
export WINEARCH=$PREFIX_ARCH

# Enable virtual desktop if VIRTUAL_DESKTOP env is set to 1
if [ $VIRTUAL_DESKTOP = 1 ]; then
	VDESKTOP="explorer /desktop=Wine,$VIRTUAL_DESKTOP_SIZE"
fi

# Get current screen resolution
if [ $RESTORE_RESOLUTION = 1 ]; then
	RESOLUTION="$(xrandr -q | sed -n -e 's/.* connected primary \([^ +]*\).*/\1/p')"
    OUTPUT="$(xrandr -q | sed -n -e 's/\([^ ]*\) connected primary.*/\1/p')"
fi

# Make Wine binaries executable
if [ -d "$DIR/wine" ] && [ ! -x "$DIR/wine/bin/wine" ]; then
	chmod -R 700 "$DIR/wine"
fi

# Use system Wine if GLIBC checking is enabled and GLIBC is older than required
if [ $USE_SYSTEM_WINE = 0 ] && [ $CHECK_GLIBC = 1 ]; then
	GLIBC_VERSION="$(ldd --version | head -n1 | sed 's/\(.*\) //g' | sed 's/\.[^.]*//2g')"

	if [ "$(echo "${GLIBC_VERSION//./}")" -lt "$(echo "${GLIBC_REQUIRED//./}")" ]; then
		USE_SYSTEM_WINE=1
		OLD_GLIBC=1
	fi
fi

# Use system Wine if needed
if [ ! -f "$WINE" ] || [ $USE_SYSTEM_WINE = 1 ]; then
	if command -v wine-development &>/dev/null; then
		WINE=wine-development
		WINE64=wine64-development
		WINESERVER=wineserver-development
	else
		WINE=wine
		WINE64=wine64
		WINESERVER=wineserver
	fi

	USE_SYSTEM_WINE=1
fi

# Check WINEARCH variable and system architecture
if [ "$WINEARCH" = "win64" ] && ! "$WINE64" --version &>/dev/null; then
		printf '%s\n' \
      'WINEARCH is set to win64.' \
		  'But seems like your Wine or your system is 32-bit.' \
		  'Use 64-bit Wine or set WINEARCH to win32.'

		if [ "$(uname -m)" != "x86_64" ]; then
			echo -e "\nYour system is 32-bit!"
		fi

		exit
elif [ "$WINEARCH" = "win32" ] && [ $USE_SYSTEM_WINE = 0 ]; then
	if [ "$(basename "$(readlink -f "$WINE")")" = "wine64" ]; then
    printf '%s\n' \
      'WINEARCH is set to win32.' \
      'But seems like your Wine is pure 64-bit without multilib support.' \
      'Use multilib (or 32-bit) Wine or set WINEARCH to win64.'
		exit
	fi
fi

# Check if Wine has PBA or ESYNC features
mkdir -p "$DIR/.temp_files"
if [ ! -f "$DIR/.temp_files/pba_status" ]; then
	if grep PBA "$DIR/wine/lib/wine/wined3d.dll.so" &>/dev/null || grep PBA "$DIR/wine/lib64/wine/wined3d.dll.so" &>/dev/null; then
		echo "yes" > "$DIR/.temp_files/pba_status"
	else
		echo "no" > "$DIR/.temp_files/pba_status"
	fi
fi

if [ ! -f "$DIR/.temp_files/esync_status" ]; then
	if grep ESYNC "$DIR/wine/lib/wine/ntdll.dll.so" &>/dev/null || grep ESYNC "$DIR/wine/lib64/wine/ntdll.dll.so" &>/dev/null; then
		echo "yes" > "$DIR/.temp_files/esync_status"
	else
		echo "no" > "$DIR/.temp_files/esync_status"
	fi
fi

if [ "$(cat "$DIR/.temp_files/pba_status")" = "no" ] || [ $USE_SYSTEM_WINE = 1 ]; then
	NO_PBA_FOUND=1
else NO_PBA_FOUND=0; fi

if [ "$(cat "$DIR/.temp_files/esync_status")" = "no" ] || [ $USE_SYSTEM_WINE = 1 ]; then
	NO_ESYNC_FOUND=1
else NO_ESYNC_FOUND=0; fi

# Disable ESYNC if ulimit fails
ESYNC_FORCE_OFF=0
if [ $NO_ESYNC_FOUND = 0 ] && [ $WINEESYNC = 1 ]; then
	if ! ulimit -n 500000 &>/dev/null; then
		export WINEESYNC=0
		ESYNC_FORCE_OFF=1
	fi
fi

## Game-specific variables

# Use game_info_SCRIPTNAME.txt file if exists
if [ -f "$DIR/game_info/game_info_$SCRIPT_NAME.txt" ]; then
	GAME_INFO="$(cat "$DIR/game_info/game_info_$SCRIPT_NAME.txt")"
else
	GAME_INFO="$(cat "$DIR/game_info/game_info.txt")"
fi

GAME="$(printf "$GAME_INFO" | sed -n 6p)"
VERSION="$(printf "$GAME_INFO" | sed -n 2p)"
GAME_PATH="$WINEPREFIX/drive_c/$(printf "$GAME_INFO" | sed -n 1p)"
EXE="$(printf "$GAME_INFO" | sed -n 3p)"
ARGS="$(printf "$GAME_INFO" | sed -n 4p)"

for arg in "$@"; do
	if [ "$arg" != "--debug" ]; then
		ARGS="$ARGS $arg"
    fi
done

### Prepare for launching game

## Exit if there is no Wine

WINE_VERSION="$("$WINE" --version)"
if [ ! "$WINE_VERSION" ]; then
	clear
	printf "There is no Wine available in your system!\n"
	exit
fi

## Exit if there is no game_info.txt file

if [ ! "$GAME_INFO" ]; then
	clear
	printf "There is no game_info.txt file!\n"
	exit
fi

## Exit if user have no write permission on directory

if ! touch "$DIR/write_test"; then
	clear
	printf '%s\n' \
    'You have no write permissions on this directory!\n\n' \
    'chmod 777 DIRNAME'
	exit
fi
rm -f "$DIR/write_test"

## Change working directory

cd "$DIR" || exit

## Setup prefix

if [ ! -d prefix ] || [ "$USERNAME" != "$(cat .temp_files/lastuser)" ] || [ "$WINE_VERSION" != "$(cat .temp_files/lastwine)" ]; then
	# Move old prefix just in case
	mv prefix "prefix_$(date '+%d.%m_%H:%M:%S')" &>/dev/null

	# Remove .temp_files directory
	rm -rf .temp_files

	# Create prefix
	printf "Creating prefix, please wait.\n\n"

	export WINEDLLOVERRIDES="$WINEDLLOVERRIDES;mscoree,mshtml="
	"$WINE" wineboot &>/dev/null
	"$WINESERVER" -w
	export WINEDLLOVERRIDES="winemenubuilder.exe="

	# Create symlink to game directory
	mkdir -p "$GAME_PATH"; rm -rf "$GAME_PATH"
	ln -sfr game_info/data "$GAME_PATH"

	# Execute files in game_info/exe directory
	if [ -d game_info/exe ]; then
		printf "Executing files\n"

		for file in game_info/exe/*; do
			printf "Executing file $file\n"

			"$WINE" start "$file" &>/dev/null
			"$WINESERVER" -w
		done
	fi

	# Apply reg files
	if [ -d game_info/regs ]; then
		printf "Importing registry files\n"

		for file in game_info/regs/*.reg; do
			printf "Importing $file\n"

			"$WINE" regedit "$file" &>/dev/null
			"$WINE64" regedit "$file" &>/dev/null
		done
	fi

	# Symlink requeired dlls, override and register them
	if [ -d game_info/dlls ]; then
		printf "Symlinking and registering dlls\n"

		printf "Windows Registry Editor Version 5.00\n" > dlloverrides.reg
		printf "[HKEY_CURRENT_USER\Software\Wine\DllOverrides]" >> dlloverrides.reg

		for x in game_info/dlls/*; do
			printf "Creating symlink to $x"

			ln -sfr "$x" "$WINEPREFIX/drive_c/windows/system32"

			# Do not override component if required
			printf -e '"'$(basename $x .dll)'"="native"\n' >> dlloverrides.reg

			# Register component with regsvr32
			printf "Registering $(basename $x)\n"

			"$WINE" regsvr32 "$(basename $x)" &>/dev/null
			"$WINE64" regsvr32 "$(basename $x)" &>/dev/null
		done

		printf "Overriding dlls\n"

		"$WINE" regedit dlloverrides.reg &>/dev/null
		"$WINE64" regedit dlloverrides.reg &>/dev/null

		rm -f dlloverrides.reg
	fi

	# Make documents directory
	printf "Sandboxing prefix"

	# Valve's Proton uses steamuser as username
	if [ -d "$WINEPREFIX/drive_c/users/steamuser" ]; then
		USERNAME=steamuser
	fi

	if [ ! -d "$DIR/documents" ]; then
		mv "$WINEPREFIX/drive_c/users/$USERNAME" "$DIR/documents" &>/dev/null
		mv "$WINEPREFIX/drive_c/users/Public" "$DIR/documents/Public"
	fi
	rm -rf "$WINEPREFIX/drive_c/users/$USERNAME"
	rm -rf "$WINEPREFIX/drive_c/users/Public"
	ln -sfr "$DIR/documents" "$WINEPREFIX/drive_c/users/$USERNAME"
	ln -sfr "$DIR/documents/Public" "$WINEPREFIX/drive_c/users/Public"
	ln -sfr "$DIR/documents" "$WINEPREFIX/drive_c/users/user"

	# Sandbox the prefix; Borrowed from winetricks scripts
	rm -f "$WINEPREFIX/dosdevices/z:"
	ln -sfr "$DIR" "$WINEPREFIX/dosdevices/k:"

	if cd "$WINEPREFIX/drive_c/users/$USERNAME"; then
		# Use one directory for all symlinks
		# This is necessary for multilocale compatibility
		mkdir -p Documents_Multilocale

		printf '%s\n' \
      'Documents_Multilocale directory is for compatibility with different languages.' \
      'Put all files into Documents_Multilocale instead of specific directories like My Documents, Мои документы etc.' \
     > Documents_Multilocale/readme.txt

		if [ "$USERNAME" != "steamuser" ]; then
			for x in *; do
				if test -h "$x" && test -d "$x"; then
					rm -f "$x"
					ln -sfr Documents_Multilocale "$x"
				fi
			done
		else
			[ -d "My Documents" ] && rm -rf "My Documents" && ln -sfr Documents_Multilocale "My Documents"
			[ -d "Мои документы" ] && rm -rf "Мои документы" && ln -sfr Documents_Multilocale "Мои документы"
		fi

		cd "$DIR" # Hug sanitizating yolo!
	fi

	"$WINE" regedit /D 'HKEY_LOCAL_MACHINE\\Software\\Microsoft\Windows\CurrentVersion\Explorer\Desktop\Namespace\{9D20AAE8-0625-44B0-9CA7-71889C2254D9}' &>/dev/null
	echo disable > "$WINEPREFIX/.update-timestamp"

	# Copy content from additional directories
	if [ -d game_info/additional ]; then
		for f in game_info/additional/*; do
			echo "Copying $f"

			cp -r "$f" "$DIR"
		done
	fi

	# Execute scripts in game_info/sh directory
	if [ -d game_info/sh ]; then
		echo "Executing scripts"

		chmod -R 700 game_info/sh

		for file in game_info/sh/*; do
			echo "Executing $file"

			"$file"
		done
	fi

	# Execute custom winetricks actions
	if [ -f game_info/winetricks_list.txt ]; then
		if [ ! -f "$DIR/winetricks" ]; then
			if ping -W 1 -c 1 8.8.8.8 &>/dev/null; then
				printf "Downloading winetricks\n"

				wget -O "$DIR/winetricks" "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" &>/dev/null
			elif command -v winetricks &>/dev/null; then
				ln -sf "$(command -v winetricks)" "$DIR/winetricks"
			fi
		fi

		if [ -f "$DIR/winetricks" ]; then
			if [ ! -x "$DIR/winetricks" ]; then
				chmod +x "$DIR/winetricks"
			fi

			printf '%s\n' \
        'winetricks $(cat game_info/winetricks_list.txt)' \
        'Executing winetricks actions, please wait.'

			"$WINESERVER" -w
			"$DIR/winetricks" $(cat game_info/winetricks_list.txt) &>/dev/null
			"$WINESERVER" -w
		else
			printf "Winetricks not found and can't be downloaded (no internet connection).\n"
		fi
	fi

	# Enable WINEDEBUG during first run
	export WINEDEBUG="err+all,fixme-all"

	# Save information about last user name and Wine version
	USERNAME="$(id -un)"

	mkdir -p .temp_files
	printf "$USERNAME" > .temp_files/lastuser
	printf "$WINE_VERSION" > .temp_files/lastwine
fi

#### You continue now, i got lazy reading this longass script - KREYREN

## Set windows version

if [ ! -f .temp_files/lastwin ] || [ "$WINDOWS_VERSION" != "$(cat .temp_files/lastwin)" ]; then
	if [ "$WINDOWS_VERSION" = "winxp" ] || [ "$WINDOWS_VERSION" = "win10" ] || [ "$WINDOWS_VERSION" = "win7" ]; then
		echo "Changing Windows version to $WINDOWS_VERSION"

		if [ "$WINDOWS_VERSION" = "winxp" ]; then
			if [ "$WINEARCH" = "win32" ]; then
				csdversion="Service Pack 3"
				currentbuildnumber="2600"
				currentversion="5.1"
				csdversion_hex=dword:00000300
			else
                csdversion="Service Pack 2"
                currentbuildnumber="3790"
                currentversion="5.2"
                csdversion_hex=dword:00000200

                "$WINE" reg add "HKLM\\System\\CurrentControlSet\\Control\\ProductOptions" /v ProductType /d "WinNT" /f &>/dev/null
             fi
		elif [ "$WINDOWS_VERSION" = "win7" ]; then
			csdversion="Service Pack 1"
			currentbuildnumber="7601"
			currentversion="6.1"
			csdversion_hex=dword:00000100

			"$WINE" reg add "HKLM\\System\\CurrentControlSet\\Control\\ProductOptions" /v ProductType /d "WinNT" /f &>/dev/null
		elif [ "$WINDOWS_VERSION" = "win10" ]; then
            csdversion=""
            currentbuildnumber="10240"
            currentversion="10.0"
            csdversion_hex=dword:00000000

            "$WINE" reg add "HKLM\\System\\CurrentControlSet\\Control\\ProductOptions" /v ProductType /d "WinNT" /f &>/dev/null
        fi

		echo -e "Windows Registry Editor Version 5.00\n" > "$WINEPREFIX/drive_c/setwinver.reg"
		echo -e "[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion]" >> "$WINEPREFIX/drive_c/setwinver.reg"
		echo -e '"CSDVersion"="'$csdversion'"' >> "$WINEPREFIX/drive_c/setwinver.reg"
		echo -e '"CurrentBuildNumber"="'$currentbuildnumber'"' >> "$WINEPREFIX/drive_c/setwinver.reg"
		echo -e '"CurrentVersion"="'$currentversion'"' >> "$WINEPREFIX/drive_c/setwinver.reg"

		echo -e "\n[HKEY_LOCAL_MACHINE\\System\\CurrentControlSet\\Control\\Windows]" >> "$WINEPREFIX/drive_c/setwinver.reg"
		echo -e '"CSDVersion"='$csdversion_hex'\n' >> "$WINEPREFIX/drive_c/setwinver.reg"

		"$WINE" regedit C:\setwinver.reg &>/dev/null
		"$WINE64" regedit C:\setwinver.reg &>/dev/null

		rm -f "$WINEPREFIX/drive_c/setwinver.reg"
		echo "$WINDOWS_VERSION" > .temp_files/lastwin
	else
		echo "Incorrect Windows version."
		echo "Please, use one of the available versions: winxp, win2k or win7."
	fi
fi

## Set sound driver to PulseAudio

if [ $USE_PULSEAUDIO = 1 ] && [ ! -f "$WINEPREFIX/drive_c/usepulse.reg" ]; then
	echo "Set audio driver to PulseAudio"

	echo -e "Windows Registry Editor Version 5.00\n" > "$WINEPREFIX/drive_c/usepulse.reg"
	echo -e "[HKEY_CURRENT_USER\\Software\\Wine\\Drivers]\n" >> "$WINEPREFIX/drive_c/usepulse.reg"
	echo -e '"Audio"="pulse"' >> "$WINEPREFIX/drive_c/usepulse.reg"

	"$WINE" regedit C:\usepulse.reg &>/dev/null
	"$WINE64" regedit C:\usepulse.reg &>/dev/null

	rm -f "$WINEPREFIX/drive_c/usealsa.reg"
elif [ $USE_PULSEAUDIO = 0 ] && [ ! -f "$WINEPREFIX/drive_c/usealsa.reg" ]; then
	echo "Set audio driver to ALSA"

	echo -e "Windows Registry Editor Version 5.00\n" > "$WINEPREFIX/drive_c/usealsa.reg"
	echo -e "[HKEY_CURRENT_USER\\Software\\Wine\\Drivers]\n" >> "$WINEPREFIX/drive_c/usealsa.reg"
	echo -e '"Audio"="alsa"' >> "$WINEPREFIX/drive_c/usealsa.reg"

	"$WINE" regedit C:\usealsa.reg &>/dev/null
	"$WINE64" regedit C:\usealsa.reg &>/dev/null

	rm -f "$WINEPREFIX/drive_c/usepulse.reg"
fi

## Disable CSMT if required

if [ $CSMT_DISABLE = 1 ] && [ ! -f "$WINEPREFIX/drive_c/csmt.reg" ]; then
	echo "Disabling CSMT"

	echo -e "Windows Registry Editor Version 5.00\n" > "$WINEPREFIX/drive_c/csmt.reg"
	echo -e "[HKEY_CURRENT_USER\Software\Wine\Direct3D]\n" >> "$WINEPREFIX/drive_c/csmt.reg"
	echo -e '"csmt"=dword:0\n' >> "$WINEPREFIX/drive_c/csmt.reg"

	"$WINE" regedit C:\csmt.reg &>/dev/null
	"$WINE64" regedit C:\csmt.reg &>/dev/null
elif [ $CSMT_DISABLE = 0 ] && [ -f "$WINEPREFIX/drive_c/csmt.reg" ]; then
	echo "Enabling CSMT"

	echo -e "Windows Registry Editor Version 5.00\n" > "$WINEPREFIX/drive_c/csmt.reg"
	echo -e "[HKEY_CURRENT_USER\Software\Wine\Direct3D]\n" >> "$WINEPREFIX/drive_c/csmt.reg"
	echo -e '"csmt"=-' >> "$WINEPREFIX/drive_c/csmt.reg"

	"$WINE" regedit C:\csmt.reg &>/dev/null
	"$WINE64" regedit C:\csmt.reg &>/dev/null

	rm -f "$WINEPREFIX/drive_c/csmt.reg"
fi

## Disable DXVK if required
## Also disable nvapi library if DXVK is enabled

if [ $DXVK = 1 ]; then
	if [ ! -f "$DIR/game_info/dlls/dxgi.dll" ] && grep dxvk "$WINEPREFIX/winetricks.log" &>/dev/null; then
		mkdir -p "$DIR/game_info/dlls"

		cp "$WINEPREFIX/drive_c/windows/system32/d3d11.dll" "$DIR/game_info/dlls"
		cp "$WINEPREFIX/drive_c/windows/system32/d3d10core.dll" "$DIR/game_info/dlls"
		cp "$WINEPREFIX/drive_c/windows/system32/d3d10.dll" "$DIR/game_info/dlls"
		cp "$WINEPREFIX/drive_c/windows/system32/d3d10_1.dll" "$DIR/game_info/dlls"
		cp "$WINEPREFIX/drive_c/windows/system32/dxgi.dll" "$DIR/game_info/dlls"
	fi
fi

if [ $DXVK = 0 ]; then
	export WINEDLLOVERRIDES="$WINEDLLOVERRIDES;dxgi,d3d10,d3d10_1,d3d10core,d3d11=b"
elif [ $DXVK = 1 ] && [ -f "$DIR/game_info/dlls/dxgi.dll" ]; then
	export WINEDLLOVERRIDES="$WINEDLLOVERRIDES;nvapi64,nvapi="

	if [ ! -d "$DIR/cache/dxvk" ]; then
		mkdir -p "$DIR/cache/dxvk"
	fi

	if [ ! -d "$WINEPREFIX/dosdevices/j:" ]; then
		ln -sfr "$DIR/cache/dxvk" "$WINEPREFIX/dosdevices/j:"
	fi
fi

## Execute custom scripts

if [ -d game_info/sh/everytime ]; then
	echo "Executing scripts"

	for file in game_info/sh/everytime/*; do
		echo "Executing $file"

		"$file"
	done
fi

## Run the game

# Output game, vars and Wine information
clear
echo "======================================================="
echo -e "\nGame: $GAME\nVersion: $VERSION"
echo -ne "\nWine: $WINE_VERSION"

if [ $USE_SYSTEM_WINE = 1 ]; then
	echo -ne " (using system Wine)"

	if [ ! -z $OLD_GLIBC ]; then echo -ne " (old GLIBC)"; fi
fi

echo -ne "\nArch: x$(echo $WINEARCH | tail -c 3)"

if [ ! -f "$DIR/game_info/dlls/dxgi.dll" ] || [ $DXVK = 0 ]; then
	if [ $CSMT_DISABLE = 1 ]; then echo -ne "\nCSMT: disabled"
	else echo -ne "\nCSMT: enabled"; fi

	if [ $NO_PBA_FOUND = 0 ]; then
		if [ $PBA_ENABLE = 0 ]; then echo -ne "\nPBA: disabled"
		else echo -ne "\nPBA: enabled"; fi
	fi

	if [ -f "$DIR/game_info/dlls/dxgi.dll" ]; then
		echo -ne "\nDXVK: disabled"
	fi
elif [ -f "$DIR/game_info/dlls/dxgi.dll" ]; then echo -ne "\nDXVK: enabled"; fi

if [ $NO_ESYNC_FOUND = 0 ]; then
	if [ $WINEESYNC = 1 ]; then echo -ne "\nESYNC: enabled"
	else echo -ne "\nESYNC: disabled"; fi

	if [ $ESYNC_FORCE_OFF = 1 ]; then echo -ne " (disabled; ulimit failed)"; fi
fi

echo -ne "\n\n======================================================="

if [ $NO_ESYNC_FOUND = 0 ] && [ $ESYNC_FORCE_OFF = 1 ]; then
	echo -ne "\n\nIf you want to enable ESYNC to improve game performance then"
	echo -ne "\nconfigure open file limit in /etc/security/limits.conf, add line:"
	echo -ne "\n\nUSERNAME hard nofile 500000"
	echo -ne "\n\nAnd then reboot your system."
	echo -ne "\n\n======================================================="
fi

if [ "$WINEDEBUG" = "-all" ]; then
	echo -ne "\n\nIf game doesn't work run the script with --debug parameter"
	echo -ne "\nto see more output: ./start.sh --debug"
else
	echo -ne "\n\nDebug mode enabled!"
fi

echo -e "\n\n======================================================="
echo

# Launch the game
cd "$GAME_PATH/$(echo "$GAME_INFO" | sed -n 5p)" || exit
"$WINESERVER" -w
"$WINE" $VDESKTOP "$EXE" $ARGS
"$WINESERVER" -w

# Restore screen resolution
if [ $RESTORE_RESOLUTION = 1 ]; then
	xrandr --output "$OUTPUT" --mode "$RESOLUTION" &>/dev/null
	xgamma -gamma 1.0 &>/dev/null
fi
