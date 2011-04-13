#!/bin/bash

## Set up the running environment
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

## Define some variables
if [ -f "$1" ] || [ -d "$1" ] || [ -L "$1" ]; then torrent="$1"; fi
if [ -d "$2" ] || [ -L "$2" ]; then alt_dest_enabled="yes" && alt_destination="$2"; fi
temp="temp"
if [[ "$(uname -a)" == *Darwin* ]]; then OS="darwin"; elif [[ "$(uname -a)" == *PCH-* ]]; then OS="pch"; else OS="other"; fi
if [ -t 1 ] && [ "$subtitles_mode" != "yes" ]; then has_display="yes"; fi
if [ "$1" == "-c" ]; then first_run="yes"; fi


##################################################################################
##                   TORRENTEXPANDER 
##                   v0.14
##
## You can use and modify this script to your convenience
## Any suggestion on how to improve this script will be welcome
##
##
## There are various ways to run this script as a daemon :
## - It can be invoked with the command torrentexpander.sh "/Path/to/your/torrent"
## - It can be triggered by the Transmission torrent client
## - You can export torrent="/Path/to/your/torrent" and start torrentexpander.sh
## - If you want Flexget to trigger torrentexpander.sh, have it echo the torrent path
##   to a file and start torrentexpander.sh. The third_party_log file will be used 
##   as a source file for torrentexpander.sh and the resulting files will then be
##   listed in this third_party_log file.
## - You can edit your settings in the torrentexpander_settings.ini file that will
##   be created the first time this script is launched. You can also access your 
##   settings by starting this script with the command /path/to/torrentexpander.sh -c
##
## If youre running this script manually you ll get a basic GUI that will enable you to
## choose a torrent file or folder and the destination where it should be expanded
## 
##################################################################################


##################################################################################
############################# REQUIRED SOFTWARE ##################################
# unrar
# unrar-nonfree
# unzip
################## SOFTWARE USED BY OPTIONAL FUNCTIONALITIES #####################
## Convert DTS track from MKV files to AC3
# https://github.com/JakeWharton/mkvdts2ac3/blob/master/mkvdts2ac3.sh
# http://www.bunkus.org/videotools/mkvtoolnix/downloads.html
# http://www.videolan.org/developers/libdca.html
# http://aften.sourceforge.net/
## Convert IMG to ISO 
# http://sourceforge.net/projects/ccd2iso/
##################################################################################
############################### END SOFTWARE #####################################


##################################################################################
################################ USER VARIABLES ##################################
########################### These variables are required #########################
################# On 1st run they will be stored in an ini file###################
## The destination folder is where files will be extracted
## It MUST be different from the one where your torrents are located
##ÊA sub directory of your torrents directory is fine though
destination_folder="/path/to/your/destination/folder/"
################################ Software paths ##################################
################# Please check if these variables are correct ####################
unrar_bin="/usr/bin/unrar"
unzip_bin="/usr/bin/unzip"
ccd2iso_bin="/usr/bin/ccd2iso"
mkvdts2ac3_bin="/path/to/mkvdts2ac3.sh"
##################### Supported file extensions - Comma separated ################
########### You must have at least one extension enabled in each field ###########
############### DON T ADD RAR OR ZIP EXTENSIONS IN THESE FIELDS ##################
supported_extensions="avi,mkv,divx,iso,img,mp3,m4a,wav,srt,idx,sub,dvd"
tv_show_extensions="avi,mkv,srt,idx,sub"
movies_extensions="avi,mkv,divx,iso,img,srt,idx,sub"
music_extensions="mp3,m4a,wav"
##################### Movies detection patterns - Comma separated ################
##################### You must have at least one pattern enabled #################
movies_detect_patterns="r5,ts,720p,1080p,dvdrip,bdrip,brrip,dvdscr,dvdr"
####################### Optional functionalities variables #######################
#################### Set these variables to "no" to disable ######################
## Fix numbering for TV Shows - Switch variable to "yes" to enable
tv_shows_fix_numbering="yes"
## Cleanup Filenames - Switch variable to "yes" to enable
clean_up_filenames="yes"
## Keep a dummy video file with the original filename for subtitles retrieval
subtitles_handling="yes"
## Repack handling - Switch variable to "yes" to enable
repack_handling="no"
## Create Wii Cuesheet - Switch variable to "yes" to enable
wii_post="no"
## Convert img to iso - Switch variable to "yes" to enable
img_post="no"
## Copy or move TV Shows to a specific folder - choose action (copy / move)
## and add path to enable
tv_shows_post="no"
tv_shows_post_path="no"
## Copy or move movies to a specific folder - choose action (copy / move)
## and add path to enable
movies_post="no"
movies_post_path="no"
## Copy or move music to a specific folder - choose action (copy / move)
## and add path to enable
music_post="no"
music_post_path="no"
## Convert DTS track from MKV files to AC3 - Switch variable to "yes" to enable and check mkvdts2ac3.sh path
dts_post="no"
## Edit files and folders permissions - If you don t know what that means set it all to "no"
user_perm_post="no"
group_perm_post="no"
files_perm_post="no"
folder_perm_post="no"
edit_perm_as_sudo="no"
## Use a source / resulting files log shared with a third party app - Add path to enable
third_party_log="no"
## Reset timestamp (mtime)
reset_timestamp="no"
############################ END USER VARIABLES ##################################
##################################################################################


##################################################################################
## Save variables to another file. Updating the script will be less painful

PRG="$0"
while [ -h "$PRG" ] ; do
	ls=`ls -ld "$PRG"`
	link=`expr "$ls" : '.*-> \(.*\)$'`
	if expr "$link" : '/.*' > /dev/null; then
		PRG="$link"
	else
		PRG="`dirname "$PRG"`/$link"
	fi
done
script_path=`dirname "$PRG"`
settings_file="$script_path/torrentexpander_settings.ini"
subtitles_directory="$script_path/torrentexpander_subtitles_dir"
if [[ "$script_path" == *torrentexpander.workflow* ]]; then subtitles_handling="no"; fi

##################################################################################
######################### Script setup user interface ############################
if [ "$has_display" == "yes" ] && [ ! -f "$settings_file" ]; then first_run="yes"; fi

## Checking settings
if [ ! -f "$settings_file" ]; then
	touch "$settings_file"
fi

check_settings=$(echo "$(cat "$settings_file")")
if [[ "$check_settings" != *estination_folder=* ]]; then
	if [ "$OS" == "pch" ] && [ ! -d "$destination_folder" ]; then echo "destination_folder="/share/Download/expanded/"" >> "$settings_file"
	elif [ "$OS" == "darwin" ] && [ ! -d "$destination_folder" ]; then echo "destination_folder="$HOME/Desktop/"" >> "$settings_file"
	else echo "destination_folder="$destination_folder"" >> "$settings_file"
	fi
fi
if [[ "$check_settings" != *nrar_bin=* ]]; then
	if [ "$OS" == "pch" ]; then echo "unrar_bin=/nmt/apps/bin/unrar" >> "$settings_file"
	elif [ "$OS" == "darwin" ] && [ -f "/Applications/rar/unrar" ]; then echo "unrar_bin=/Applications/rar/unrar" >> "$settings_file"
	elif [ "$OS" == "darwin" ] && [ -f "$HOME/Applications/rar/unrar" ]; then echo "unrar_bin=$HOME/Applications/rar/unrar" >> "$settings_file"
	else echo "unrar_bin="$unrar_bin"" >> "$settings_file"
	fi
fi
if [[ "$check_settings" != *nzip_bin=* ]]; then echo "unzip_bin="$unzip_bin"" >> "$settings_file"; fi
if [[ "$check_settings" != *cd2iso_bin=* ]]; then echo "ccd2iso_bin="$ccd2iso_bin"" >> "$settings_file"; fi
if [[ "$check_settings" != *kvdts2ac3_bin=* ]]; then echo "mkvdts2ac3_bin="$mkvdts2ac3_bin"" >> "$settings_file"; fi
if [[ "$check_settings" != *v_shows_fix_numbering=* ]]; then echo "tv_shows_fix_numbering="$tv_shows_fix_numbering"" >> "$settings_file"; fi
if [[ "$check_settings" != *lean_up_filenames=* ]]; then echo "clean_up_filenames="$clean_up_filenames"" >> "$settings_file"; fi
if [[ "$check_settings" != *ubtitles_handling=* ]]; then echo "subtitles_handling="$subtitles_handling"" >> "$settings_file"; fi
if [[ "$check_settings" != *epack_handling=* ]]; then echo "repack_handling="$repack_handling"" >> "$settings_file"; fi
if [[ "$check_settings" != *ii_post=* ]]; then echo "wii_post="$wii_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *mg_post=* ]]; then echo "img_post="$img_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *v_shows_post=* ]]; then echo "tv_shows_post="$tv_shows_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *v_shows_post_path=* ]]; then echo "tv_shows_post_path="$tv_shows_post_path"" >> "$settings_file"; fi
if [[ "$check_settings" != *ovies_post=* ]]; then echo "movies_post="$movies_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *ovies_post_path=* ]]; then echo "movies_post_path="$movies_post_path"" >> "$settings_file"; fi
if [[ "$check_settings" != *usic_post=* ]]; then echo "music_post="$music_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *usic_post_path=* ]]; then echo "music_post_path="$music_post_path"" >> "$settings_file"; fi
if [[ "$check_settings" != *ts_post=* ]]; then echo "dts_post="$dts_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *ser_perm_post=* ]]; then echo "user_perm_post="$user_perm_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *roup_perm_post=* ]]; then echo "group_perm_post="$group_perm_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *iles_perm_post=* ]]; then echo "files_perm_post="$files_perm_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *older_perm_post=* ]]; then echo "folder_perm_post="$folder_perm_post"" >> "$settings_file"; fi
if [[ "$check_settings" != *dit_perm_as_sudo=* ]]; then echo "edit_perm_as_sudo="$edit_perm_as_sudo"" >> "$settings_file"; fi
if [[ "$check_settings" != *third_party_log=* ]]; then echo "third_party_log="$third_party_log"" >> "$settings_file"; fi
if [[ "$check_settings" != *eset_timestamp=* ]]; then echo "reset_timestamp="$reset_timestamp"" >> "$settings_file"; fi
if [[ "$check_settings" != *upported_extensions=* ]]; then echo "supported_extensions="$supported_extensions"" >> "$settings_file"; fi
if [[ "$check_settings" != *v_show_extensions=* ]]; then echo "tv_show_extensions="$tv_show_extensions"" >> "$settings_file"; fi
if [[ "$check_settings" != *ovies_extensions=* ]]; then echo "movies_extensions="$movies_extensions"" >> "$settings_file"; fi
if [[ "$check_settings" != *usic_extensions=* ]]; then echo "music_extensions="$music_extensions"" >> "$settings_file"; fi
if [[ "$check_settings" != *ovies_detect_patterns=* ]]; then echo "movies_detect_patterns="$movies_detect_patterns"" >> "$settings_file"; fi
if [ "$(echo "$check_settings" | egrep -i "([^\\]) ")" ] && [ "$OS" == "darwin" ]; then sed -i '' 's;\([^\\]\) ;\1\\ ;g' "$settings_file"; fi
if [ "$(echo "$check_settings" | egrep -i "([^\\]) ")" ] && [ "$OS" != "darwin" ]; then sed -i 's;\([^\\]\) ;\1\\ ;g' "$settings_file"; fi

source "$settings_file"

if [[ "$tv_shows_post_path" != */ ]] && [ "$tv_shows_post" != "no" ]; then tv_shows_post_path="$tv_shows_post_path/"; fi
if [[ "$music_post_path" != */ ]] && [ "$music_post_path" != "no" ]; then music_post_path="$music_post_path/"; fi
if [[ "$movies_post_path" != */ ]] && [ "$movies_post_path" != "no" ]; then movies_post_path="$movies_post_path/"; fi
supported_extensions_rev="\.$(echo $supported_extensions | sed 's;,;\$\|\\\.;g')$"
tv_show_extensions_rev="\.$(echo $tv_show_extensions | sed 's;,;\$\|\\\.;g')$"
movies_extensions_rev="\.$(echo $movies_extensions | sed 's;,;\$\|\\\.;g')$"
music_extensions_rev="\.$(echo $music_extensions | sed 's;,;\$\|\\\.;g')$"
movies_detect_patterns_rev="[^[:alnum:]]$(echo $movies_detect_patterns | sed 's;,;[^[:alnum:]]|[^[:alnum:]];g')[^[:alnum:]]"

##################################################################################
############################### Setup Assistant ##################################
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then echo -e "----------------------------------------------------\n----------------------------------------------------\n\nWELCOME TO TORRENTEXPANDER\n\n----------------------------------------------------\n----------------------------------------------------\n\n"; fi
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then echo -e "This is the first time you're running this script\nA few settings are required for it to run\nThese required settings are :\n- The destination_folder -> This is where the content of your torrents will be expanded / copied\n- unrar_bin -> This is the path to the Unrar binary. If it's not already installed on your computer then Google is your friend\n- unzip_bin -> This is the path to the Unrar binary. It's probably already installed on your computer\n\nAll other options are already set to their default value\nIf you want more details about those options, open this script with a text editor\n\nA nano editor will now open so that you can edit your settings\nTo save them you'll have to press Control-X then Y then Enter\n\nOnce you're ready press Enter" && read -p ""; fi
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then nano "$settings_file" && echo -e "\n\nYou're done with your setup\nThis script will exit now\nIf you need to edit your settings again just run $script_path/torrentexpander.sh -c" && exit; fi

##################################################################################
###################### Kinda graphical user interface ############################
if [[ "$has_display" == "yes" && ! "$torrent" ]] || [[ "$has_display" == "yes" && ! "$alt_dest_enabled" ]]; then echo -e "----------------------------------------------------\n----------------------------------------------------\n\nWELCOME TO TORRENTEXPANDER\n\n----------------------------------------------------\n----------------------------------------------------\n\n"; fi
transmission_settings_file="$(if [ "$OS" == "pch" ]; then echo "/share/.transmission/settings.json"; elif [ "$OS" == "other" ]; then echo "$HOME/.config/transmission/settings.json"; fi)"
if [ "$has_display" == "yes" ] && [ -f "$transmission_settings_file" ] && [ ! "$torrent" ]; then cd "$(echo "$(sed -n '/"download-dir": /p' "$transmission_settings_file")" | sed -e 's/    "download-dir": "//g' -e 's/", //g')"; elif [ "$has_display" == "yes" ] && [ ! -f "$transmission_settings_file" ] && [ ! "$torrent" ]; then cd "$HOME"; fi
selected=0
item_selected=""
if [ "$has_display" == "yes" ] && [ ! "$torrent" ]; then
	while [[ $selected -eq 0 ]] ; do
		count=-1 && echo "Select Torrent Source :" && echo "" && echo "$(pwd)" && echo ""
		for item in $(echo -e "Select current folder\n..\n$(ls -1)"); do
			count=$(( $count + 1 ))
			var_name="sel$count"
			var_val="$item"
			eval ${var_name}=`echo -ne \""${var_val}"\"`
			echo "$count - $item"
		done
		echo "" && echo "Type the ID of the Torrent Source :"
		read answer && sel_item="$(echo "sel$answer")"
		item_selected=${!sel_item}
		if [ "$item_selected" == "Select current folder" ]; then item_selected="$(pwd)" && selected=1
		elif [ "$item_selected" == ".." ]; then cd "$(dirname $(pwd))"
		elif [ -d "$(pwd)/$item_selected" ]; then cd "$(pwd)/$item_selected"
		elif [ -f "$(pwd)/$item_selected" ]; then item_selected="$(pwd)/$item_selected" && selected=1
		fi
		echo ""
	done
fi
if [ "$has_display" == "yes" ] && [ ! "$torrent" ] && [ "$item_selected" ] && [[ $selected -eq 1 ]]; then torrent="$item_selected" && echo "" && echo "Your File Source is $torrent" && echo "" && echo ""; fi


if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ] && [ "$gui_transmission_destination" ]; then cd "$gui_transmission_destination"; elif [ "$OS" == "pch" ] && [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ]; then cd "/share/"; elif [[ "$has_display" == "yes" && ! "$alt_dest_enabled" && ! "$alt_destination" && -d "$destination_folder" ]] || [[ "$has_display" == "yes" && ! "$alt_dest_enabled" && ! "$alt_destination" && -L "$destination_folder" ]]; then cd "$destination_folder"; elif [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ]; then cd "$HOME"; fi
selected=0
item_selected=""
if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ]; then
	while [[ $selected -eq 0 ]] ; do
		count=-1 && echo "" && echo "Select Destination Folder :" && echo "" && echo "$(pwd)" && echo ""
		for item in $(echo -e "Select current folder\n..\n$(ls -1)"); do
			count=$(( $count + 1 ))
			var_name="sel$count"
			var_val="$item"
			eval ${var_name}=`echo -ne \""${var_val}"\"`
			echo "$count  -  $item"
		done
		echo "" && echo "Type the ID of the Destination Folder :"
		read answer && sel_item="$(echo "sel$answer")"
		item_selected=${!sel_item}
		if [ "$item_selected" == "Select current folder" ]; then item_selected="$(pwd)" && selected=1
		elif [ "$item_selected" == ".." ]; then cd "$(dirname $(pwd))"
		elif [ -d "$(pwd)/$item_selected" ]; then cd "$(pwd)/$item_selected"
		elif [ -f "$(pwd)/$item_selected" ]; then cd "$(pwd)"
		fi
		echo ""
	done
fi

if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ] && [ "$item_selected" ] && [[ $selected -eq 1 ]]; then alt_dest_enabled="yes" && alt_destination="$item_selected" && echo "" && echo "Your Destination Folder is $alt_destination" && echo "" && echo ""; fi

if [ "$alt_dest_enabled" == "yes" ]; then destination_folder=`echo "$alt_destination"`; fi
if [[ "$destination_folder" != */ ]]; then destination_folder="$destination_folder/"; fi

## This temp folder is used for zip archives and dts conversion and will be
## automatically removed. By default it will be created in your destination folder
torrentexpander_temp="torrentexpander_temp"
temp_folder="$(echo "$destination_folder$torrentexpander_temp/")"

##################################################################################
############################# TORRENT SOURCE SETUP ###############################
################# You probably dont need to do anything here #####################
## This script will use a variable named torrent if file, else cd variable torrent, 
## else use transmission variables if file, else cd transmission variables,
## else use current folder
if [ "$TR_TORRENT_NAME" ] && [ ! "$torrent" ]; then torrent="$TR_TORRENT_DIR/$TR_TORRENT_NAME"; fi
if [ -f "$torrent" ] || [ -d "$torrent" ] || [ -L "$torrent" ]; then
	delete_third_party_log="yes"
	if [ -d "$torrent" ] || [ -L "$torrent" ]; then cd "$torrent" && current_folder=`echo "$(pwd)"` && folder_short=`echo "$( basename "$(pwd)" )"` && torrent=""; fi
elif [ "$third_party_log" != "no" ] && [ -f "$third_party_log" ]; then
	torrent="$(cat "$third_party_log")"
	if [ -d "$torrent" ] || [ -L "$torrent" ]; then cd "$torrent" && current_folder=`echo "$(pwd)"` && folder_short=`echo "$( basename "$(pwd)" )"` && torrent=""; fi
elif [ "$has_display" == "yes" ]; then
	echo "I cannot detect any Torrent Source - This script will exit" && exit
else exit
fi

######################### END TORRENT SOURCE SETUP ###############################
##################################################################################

##################### CHECKING IF SCRIPT IS ALREADY RUNNING ######################
script_notif="torrentexpander is running"
log_file="$(echo "$destination_folder$script_notif")"

while [ -f "$log_file" ]; do
	if [ "$has_display" == "yes" ]; then echo "Waiting for another instance of the script to end . . . . . ."; fi
	sleep 15
done

if [ ! -f "$log_file" ]; then
	touch "$log_file"
fi

##################################################################################

##################### CHECKING IF VARIABLES ARE CORRECT ##########################
variables_check="Please check your script variables"
temp_directory="$(echo "$(dirname "$temp_folder")")"
third_party_log_directory="$(echo "$(dirname "$third_party_log")")"
errors_file="$script_path/torrentexpander_errors.log"
if [ "$torrent" ] && [ ! "$current_folder" ]; then
	torrent_directory="$(echo "$(dirname "$torrent")/")"
elif [ "$current_folder" ] && [ ! "$torrent" ]; then
	torrent_directory="$(echo "$(dirname "$current_folder")/")"
fi

if [ -f "$errors_file" ]; then rm -f "$errors_file"; fi

if [ ! -d "$destination_folder" ] && [ ! -L "$destination_folder" ]; then
	echo "Your destination folder is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your destination folder is incorrect please edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [ ! -d "$temp_directory" ] && [ ! -L "$temp_directory" ]; then
	echo "Your temp folder path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your temp folder path is incorrect please edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [ -d "$temp_folder" ] || [ -L "$temp_folder" ]; then
	echo "Temp folder already exists. Please delete it or edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Temp folder already exists. Please delete it or edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [ "$torrent_directory" == "$destination_folder" ]; then
	echo "Your destination folder should be different from the one where your torrent is located. Please edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your destination folder should be different from the one where your torrent is located. Please edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [ ! -d "$third_party_log_directory" ] && [ ! -L "$third_party_log_directory" ] && [ "$third_party_log" != "no" ]; then
	echo "Your third party log path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your third party log path is incorrect please edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [ ! -f "$unrar_bin" ] && [ ! -L "$unrar_bin" ]; then
	echo "Your Unrar path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your Unrar path is incorrect please edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [ ! -f "$unzip_bin" ] && [ ! -L "$unzip_bin" ]; then
	echo "Your Unzip path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your Unzip path is incorrect please edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [[ "$supported_extensions_rev" =~ rar ]] || [[ "$tv_show_extensions_rev" =~ rar ]] || [[ "$movies_extensions_rev" =~ rar ]] || [[ "$music_extensions_rev" =~ rar ]] || [[ "$supported_extensions_rev" =~ zip ]] || [[ "$tv_show_extensions_rev" =~ zip ]] || [[ "$movies_extensions_rev" =~ zip ]] || [[ "$music_extensions_rev" =~ zip ]]; then
	echo "Your supported file extensions are incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your supported file extensions are incorrect please edit your torrentexpander_settings.ini file";  fi
	quit_on_error="yes"
fi
if [ ! -d "$tv_shows_post_path" ] && [ ! -L "$tv_shows_post_path" ] && [ "$tv_shows_post" != "no" ]; then
	echo "Your TV Shows path is incorrect - TV Shows Post will be disabled" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your TV Shows path is incorrect - TV Shows Post will be disabled";  fi
	tv_shows_post="no"
fi
if [ ! -d "$music_post_path" ] && [ ! -L "$music_post_path" ] && [ "$music_post" != "no" ]; then
	echo "Your music path is incorrect - Music Post will be disabled" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your music path is incorrect - Music Post will be disabled";  fi
	music_post="no"
fi
if [ ! -d "$movies_post_path" ] && [ ! -L "$movies_post_path" ] && [ "$movies_post" != "no" ]; then
	echo "Your movies path is incorrect - Movies Post will be disabled" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Your movies path is incorrect - Movies Post will be disabled";  fi
	movies_post="no"
fi
if [ ! -f "$mkvdts2ac3_bin" ] && [ ! -L "$mkvdts2ac3_bin" ] && [ "$dts_post" == "yes" ]; then
	echo "Path to mkvdts2ac3.sh is incorrect - DTS Post will be disabled" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Path to mkvdts2ac3.sh is incorrect - DTS Post will be disabled";  fi
	dts_post="no"
fi
if [ ! -f "$ccd2iso_bin" ] && [ ! -L "$ccd2iso_bin" ] && [ "$img_post" == "yes" ]; then
	echo "Path to ccd2iso is incorrect - IMG to ISO Post will be disabled" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Path to ccd2iso is incorrect - IMG to ISO Post will be disabled";  fi
	img_post="no"
fi
if [[ "$third_party_log" != "no" && -f "$third_party_log" ]] || [ "$alt_dest_enabled" == "yes" ]; then
	if [ "$tv_shows_post" != "no" ]; then tv_shows_post="copy"; fi
	if [ "$music_post" != "no" ]; then music_post="copy"; fi
	if [ "$movies_post" != "no" ]; then movies_post="copy"; fi
fi
if [ "$quit_on_error" == "yes" ]; then
	if [ "$has_display" == "yes" ]; then echo -e "\n\nThere's something wrong with your settings. Please review them now." && read -p "" && nano "$settings_file" && echo -e "\n\nYou're done with your setup\nThis script will exit now\nIf you need to edit your settings again just run $script_path/torrentexpander.sh -c"; fi
	rm -f "$log_file"
	exit
fi

##################################################################################
step_number=0

## Add file to log
if [ "$torrent" ]; then
	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Checking content of the torrent";  fi
	if [ "$(echo "$torrent" | egrep -i "$supported_extensions_rev" )" ]; then
		single_file=`echo "$torrent" | egrep -i "$supported_extensions_rev"`;
		echo "$(basename "$single_file")" >> "$log_file"
	elif [ "$(echo "$torrent" | fgrep -i .rar )" ]; then
		single_file=`echo "$torrent" | fgrep -i .rar`;
		"$unrar_bin" lb -y -p- "$single_file" >> "$log_file"
	elif [ "$(echo "$torrent" | fgrep .zip )" ]; then
		single_file=`echo "$torrent" | fgrep -i .zip`
		"$unzip_bin" -o -j "$single_file" -d "$temp_folder" > /dev/null 2>&1 && ls -1 "$temp_folder" >> "$log_file" && rm -rf "$temp_folder"
	fi
fi


## Copying file to the destination folder
if [ "$torrent" ]; then
	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Expanding / moving content of the torrent";  fi
	if [ "$(echo "$torrent" | egrep -i "$supported_extensions_rev" )" ]; then
		single_file=`echo "$torrent" | egrep -i "$supported_extensions_rev"`;
		cp -f "$single_file" "$destination_folder"
	elif [ "$(echo "$torrent" | fgrep -i .rar )" ]; then
		single_file=`echo "$torrent" | fgrep -i .rar`;
		if [ "$has_display" == "yes" ]; then "$unrar_bin" e -y -ep -o+ -p- "$single_file" "$destination_folder"; else "$unrar_bin" -y -ep -o+ -p- "$single_file" "$destination_folder" > /dev/null 2>&1; fi
	elif [ "$(echo "$torrent" | fgrep .zip )" ]; then
		single_file=`echo "$torrent" | fgrep -i .zip`
		if [ "$has_display" == "yes" ]; then "$unzip_bin" -o -j "$single_file" -d "$destination_folder"; else "$unzip_bin" -o -j "$single_file" -d "$destination_folder" > /dev/null 2>&1; fi
	fi
fi


## Gathering list from folders
if [ "$current_folder" ]; then
	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Checking content of the torrent";  fi
	if [ "$OS" == "pch" ]; then
	for directory in $(find "$current_folder" -type d); do
		if [[ "$directory" == *.AppleDouble ]]; then
			echo "" > /dev/null 2>&1
		elif [ "$(ls $directory | fgrep -i part001.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part001.rar`;
			searchPath="$directory/$rarFile"
			"$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep -i part01.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part01.rar`;
			searchPath="$directory/$rarFile"
			"$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep -i .rar )" ]; then
			rarFile=`ls $directory | fgrep -i .rar`;
			searchPath="$directory/$rarFile"
			"$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep -i .001 )" ]; then
			rarFile=`ls $directory | fgrep -i .001`;
			searchPath="$directory/$rarFile"
			"$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep .zip )" ]; then
			zipFiles=`ls $directory | fgrep -i .zip`
			searchPath="$directory/$zipFiles"
			"$unzip_bin" -o -j "$searchPath" -d "$temp_folder" && ls -1 "$temp_folder" >> "$log_file" && rm -rf "$temp_folder"
		elif [ "$(ls $directory | egrep -i "$music_extensions_rev" )" ]; then
			audioFiles=`ls $directory | egrep -i "$music_extensions_rev"`;
			for f in $(echo -e "$audioFiles"); do
				item=`echo "$directory/$f"`;
				item_short=`echo "$f"`
				depth=$(( $(echo "$directory/" | sed "s;$torrent_directory;;g" | sed "s;[^/];;g" | wc -c) - 1 ))
				if [[ $depth -eq 1 ]]; then destination_name="$item_short"; elif [[ $depth -gt 1 ]]; then destination_name="$(echo "$item" | sed "s;$current_folder/;;g" | sed "s;/; - ;g")"; fi
				echo "$destination_name" >> "$log_file"
			done
		elif [ "$(ls $directory | egrep -i "$supported_extensions_rev" )" ]; then
			otherFiles=`ls $directory | egrep -i "$supported_extensions_rev"`;
			item=`echo "$otherFiles"` && echo "$item" >> "$log_file"
		fi
	done
	else
	for directory in $(find -L "$current_folder" -type d); do
		if [[ "$directory" == *.AppleDouble ]]; then
			echo "" > /dev/null 2>&1
		elif [ "$(ls $directory | fgrep -i part001.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part001.rar`;
			searchPath="$directory/$rarFile"
			nice -n 15 "$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep -i part01.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part01.rar`;
			searchPath="$directory/$rarFile"
			nice -n 15 "$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep -i .rar )" ]; then
			rarFile=`ls $directory | fgrep -i .rar`;
			searchPath="$directory/$rarFile"
			nice -n 15 "$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep -i .001 )" ]; then
			rarFile=`ls $directory | fgrep -i .001`;
			searchPath="$directory/$rarFile"
			nice -n 15 "$unrar_bin" lb -y -p- $searchPath >> "$log_file"
		elif [ "$(ls $directory | fgrep .zip )" ]; then
			zipFiles=`ls $directory | fgrep -i .zip`
			searchPath="$directory/$zipFiles"
			nice -n 15 "$unzip_bin" -o -j "$searchPath" -d "$temp_folder" && ls -1 "$temp_folder" >> "$log_file" && rm -rf "$temp_folder"
		elif [ "$(ls $directory | egrep -i "$music_extensions_rev" )" ]; then
			audioFiles=`ls $directory | egrep -i "$music_extensions_rev"`;
			for f in $(echo -e "$audioFiles"); do
				item=`echo "$directory/$f"`;
				item_short=`echo "$f"`
				depth=$(( $(echo "$directory/" | sed "s;$torrent_directory;;g" | sed "s;[^/];;g" | wc -c) - 1 ))
				if [[ $depth -eq 1 ]]; then destination_name="$item_short"; elif [[ $depth -gt 1 ]]; then destination_name="$(echo "$item" | sed "s;$current_folder/;;g" | sed "s;/; - ;g")"; fi
				echo "$destination_name" >> "$log_file"
			done
		elif [ "$(ls $directory | egrep -i "$supported_extensions_rev" )" ]; then
			otherFiles=`ls $directory | egrep -i "$supported_extensions_rev"`;
			item=`echo "$otherFiles"` && echo "$item" >> "$log_file"
		fi
	done
	fi
fi


## Expanding and copying folders to the destination folder
if [ "$current_folder" ]; then
	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Expanding / moving content of the torrent";  fi
	if [ "$OS" == "pch" ]; then
	for directory in $(find "$current_folder" -type d); do
		if [[ "$directory" == *.AppleDouble ]]; then
			echo "" > /dev/null 2>&1
		elif [ "$(ls $directory | fgrep -i part001.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part001.rar`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep -i part01.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part01.rar`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep -i .rar )" ]; then
			rarFile=`ls $directory | fgrep -i .rar`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep -i .001 )" ]; then
			rarFile=`ls $directory | fgrep -i .001`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep .zip )" ]; then
			zipFiles=`ls $directory | fgrep -i .zip`
			searchPath="$directory/$zipFiles"
			if [ "$has_display" == "yes" ]; then "$unzip_bin" -o -j "$searchPath" -d "$destination_folder"; else "$unzip_bin" -o -j "$searchPath" -d "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | egrep -i "$music_extensions_rev" )" ]; then
			audioFiles=`ls $directory | egrep -i "$music_extensions_rev"`;
			for f in $(echo -e "$audioFiles"); do
				item=`echo "$directory/$f"`;
				depth=$(( $(echo "$directory/" | sed "s;$torrent_directory;;g" | sed "s;[^/];;g" | wc -c) - 1 ))
				if [[ $depth -eq 1 ]]; then destination_name="$destination_folder"; elif [[ $depth -gt 1 ]]; then destination_name="$destination_folder$(echo "$item" | sed "s;$current_folder/;;g" | sed "s;/; - ;g")"; fi
				cp -f "$item" "$destination_name"
			done
		elif [ "$(ls $directory | egrep -i "$supported_extensions_rev" )" ]; then
			otherFiles=`ls $directory | egrep -i "$supported_extensions_rev"`;
			for f in $(echo -e "$otherFiles"); do item=`echo "$directory/$f"`; cp -f "$item" "$destination_folder"; done
		fi
	done
	else
	for directory in $(find -L "$current_folder" -type d); do
		if [[ "$directory" == *.AppleDouble ]]; then
			echo "" > /dev/null 2>&1
		elif [ "$(ls $directory | fgrep -i part001.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part001.rar`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep -i part01.rar )" ]; then
			rarFile=`ls $directory | fgrep -i part01.rar`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep -i .rar )" ]; then
			rarFile=`ls $directory | fgrep -i .rar`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep -i .001 )" ]; then
			rarFile=`ls $directory | fgrep -i .001`;
			searchPath="$directory/$rarFile"
			if [ "$has_display" == "yes" ]; then nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder"; else nice -n 15 "$unrar_bin" e -y -ep -o+ -p- "$searchPath" "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | fgrep .zip )" ]; then
			zipFiles=`ls $directory | fgrep -i .zip`
			searchPath="$directory/$zipFiles"
			if [ "$has_display" == "yes" ]; then nice -n 15 "$unzip_bin" -o -j "$searchPath" -d "$destination_folder"; else nice -n 15 "$unzip_bin" -o -j "$searchPath" -d "$destination_folder" > /dev/null 2>&1; fi
		elif [ "$(ls $directory | egrep -i "$music_extensions_rev" )" ]; then
			audioFiles=`ls $directory | egrep -i "$music_extensions_rev"`;
			for f in $(echo -e "$audioFiles"); do
				item=`echo "$directory/$f"`;
				depth=$(( $(echo "$directory/" | sed "s;$torrent_directory;;g" | sed "s;[^/];;g" | wc -c) - 1 ))
				if [[ $depth -eq 1 ]]; then destination_name="$destination_folder"; elif [[ $depth -gt 1 ]]; then destination_name="$destination_folder$(echo "$item" | sed "s;$current_folder/;;g" | sed "s;/; - ;g")"; fi
				nice -n 15 cp -f "$item" "$destination_name"
			done
		elif [ "$(ls $directory | egrep -i "$supported_extensions_rev" )" ]; then
			otherFiles=`ls $directory | egrep -i "$supported_extensions_rev"`;
			for f in $(echo -e "$otherFiles"); do item=`echo "$directory/$f"`; nice -n 15 cp -f "$item" "$destination_folder"; done
		fi
	done
	fi
fi


## if rar in rar unrar again - for idx subtitles
for line in $(cat "$log_file"); do
	if [ "$(echo "$line" | fgrep -i .rar )" ]; then
		rarFile=`echo "$line" | fgrep -i .rar`;
		"$unrar_bin" lb -y -p- "$destination_folder$rarFile" >> "$log_file" && "$unrar_bin" e -y -ep -o+ -p- "$destination_folder$rarFile" "$destination_folder" > /dev/null 2>&1
	fi
done
for line in $(cat "$log_file"); do
	if [ "$(echo "$line" | fgrep -i .rar )" ]; then
		rarFile=`echo "$line" | fgrep -i .rar`;
		rm -f "$destination_folder$rarFile" && if [ "$OS" == "darwin" ]; then sed -i '' "/$rarFile/d" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "/$rarFile/d" "$log_file"; fi
	fi
done


## Remove unexpanded and dir from rar archives in log
for line in $(cat "$log_file"); do
	item=`echo "$destination_folder$line"`
	if [ ! -f "$item" ] && [ ! -L "$item" ]; then
		if [ "$OS" == "darwin" ]; then sed -i '' "/$line/d" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "/$line/d" "$log_file"; fi
	fi
done

## Remove sample files
for line in $(cat "$log_file"); do
	if [[ "$(echo "$line" | egrep -i "^sample[^A-Za-z0-9_]" )" && "$(echo "$line" | egrep -i "\.avi$|\.mkv$|\.ts$" )" ]] || [[ "$(echo "$line" | egrep -i "[^A-Za-z0-9_]sample[^A-Za-z0-9_]" )" && "$(echo "$line" | egrep -i "\.avi$|\.mkv$|\.ts$" )" ]]; then
		sample=`echo "$line"`;
		sample_path=`echo "$destination_folder$sample"`;
		rm -f "$sample_path"
		if [ "$OS" == "darwin" ]; then sed -i '' "/^$sample$/d" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "/^$sample$/d" "$log_file"; fi
	fi
done


## Count number of resulting files
count=0 && files=$(( $count + $(cat "$log_file"|wc -l) ))
if [ "$has_display" == "yes" ] && [[ $files -eq 0 ]]; then rm -f "$log_file" && echo "Sorry, I cannot detect any file" && exit;  fi
if [[ $files -eq 0 ]]; then rm -f "$log_file" && exit;  fi


## Get file extension (only used if more that one resulting file)
for line in $(cat "$log_file"); do
	item=`echo "$line" | sed 's;.*\.;.;'`;
	extension="$item"
done

## Add destination path
if [ "$OS" == "darwin" ]; then sed -i '' "s;^;$destination_folder;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;^;$destination_folder;g" "$log_file"; fi


## If only one resulting file rename it according to its initial folder and edit log_file accordingly
if [ "$has_display" == "yes" ] && [[ $files -eq 1 ]] && [ "$folder_short" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Renaming content of the torrent";  fi
for line in $(cat "$log_file"); do
	if [[ $files -eq 1 ]] && [ "$folder_short" ]; then
		item=`echo "$line"`
		item_basename=`echo "$(basename "$line")"`
		item_renamed=`echo "$folder_short$extension"`
		item_new=`echo "$destination_folder$folder_short$extension"`
		subtitles_dest=`echo "$subtitles_directory/$(basename "$line")"`
		if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" == "yes" && "$(echo "$line" | egrep -i "\.avi$|\.mkv$|\.divx$")" ]]; then mkdir -p "$subtitles_directory" && echo "$item_renamed" > "$subtitles_dest"; fi
		if [ "$item" != "$item_new" ]; then
			if [ "$has_display" == "yes" ]; then echo "- Renaming $item_basename to $item_renamed";  fi
			mv -f "$item" "$item_new"
			if [ "$OS" == "darwin" ]; then sed -i '' "s;$item;$item_new;g" "$log_file"
			elif [ "$OS" != "darwin" ]; then sed -i "s;$item;$item_new;g" "$log_file"
			fi
		fi
		folder_short=""
	fi
done


## If more than one file, create folder named as the initial one and move the resulting files there
for line in $(cat "$log_file"); do
	if [[ $files -gt 1 ]] && [ "$folder_short" ]; then
		new_dir=`echo "$destination_folder$folder_short/"`
		source=`echo "$line"`
		item=`echo "$(basename "$source")"`
		new_item=`echo "$folder_short/$item"`
		subtitles_dest=`echo "$subtitles_directory/$(basename "$line")"`
		already_subtitles=`echo "$(echo "$source" | sed 's/\(.*\)\..*/\1\.srt/')"`
		if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" == "yes" && "$(echo "$line" | egrep -i "\.avi$|\.mkv$|\.divx$")" && ! -f "$already_subtitles" ]]; then mkdir -p "$subtitles_directory" && echo "$item" > "$subtitles_dest"; fi
		mkdir -p "$new_dir" && mv -f "$source" "$new_dir"
		if [ "$OS" == "darwin" ]; then sed -i '' "s;$item;$new_item;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$item;$new_item;g" "$log_file"; fi
	elif [[ $files -gt 1 ]] && [ ! "$folder_short" ] && [ "$torrent" ]; then
		folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
		new_dir=`echo "$destination_folder$folder_short/"`
		source=`echo "$line"`
		item=`echo "$(basename "$source")"`
		new_item=`echo "$folder_short/$item"`
		subtitles_dest=`echo "$subtitles_directory/$(basename "$line")"`
		already_subtitles=`echo "$(echo "$source" | sed 's/\(.*\)\..*/\1\.srt/')"`
		if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" == "yes" && "$(echo "$line" | egrep -i "\.avi$|\.mkv$|\.divx$")" && ! -f "$already_subtitles" ]]; then mkdir -p "$subtitles_directory" && echo "$item" > "$subtitles_dest"; fi
		mkdir -p "$new_dir" && mv -f "$source" "$new_dir"
		if [ "$OS" == "darwin" ]; then sed -i '' "s;$item;$new_item;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$item;$new_item;g" "$log_file"; fi
	fi
done


######################### Optional functionalities ################################

if [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" ]]; then echo "$destination_folder$folder_short" >> "$log_file"; fi

## Try to solve TV Shown Numbering issues
if [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([123456789])([xX])([0-9])([0-9])")" ]] || [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([01])([0-9])([0-9])([0-9])([^pPiI])")" ]] || [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Trying to solve TV Shows numbering issues";  fi
if [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([123456789])([xX])([0-9])([0-9])")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([01])([0-9])([0-9])([0-9])([^pPiI])")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" ]]; then for line in $(cat "$log_file"); do
	item=`echo "$(basename "$line")"`;
	ren_file=`echo "$item"`;
	source=`echo "$line"`;
	if [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([123456789])([xX])([0-9])([0-9])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([123456789])([xX])([0-9])([0-9])")" && -d "$line" ]]; then
		ren_file=`echo "$item" | sed 's;\([123456789]\)\([xX]\)\([0-9]\)\([0-9]\);S0\1E\3\4;g'`;
	elif [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([01])([0-9])([0-9])([0-9])([^pPiI])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([01])([0-9])([0-9])([0-9])([^pPiI])")" && -d "$line" ]]; then
		ren_file=`echo "$item" | sed 's;\([01]\)\([0-9]\)\([0-9]\)\([0-9]\)\([^pPiI]\);S\1\2E\3\4\5;g'`;
	elif [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" && -d "$line" ]]; then
		ren_file=`echo "$item" | sed 's;\([^eE]\)\([12345689]\)\([012345]\)\([0-9]\)\([^0123456789pPiI]\);\1S0\2E\3\4\5;g'`;
	fi
	bis="_bis"
	ren_location=`echo "$(dirname "$source")/$ren_file"`;
	ren_temp_location=`echo "$(dirname "$source")/$ren_file$bis"`;
	source_bis=`echo "$line"`;
	if [ "$has_display" == "yes" ] && [ "$item" != "$ren_file" ]; then echo "- Renaming $item to $ren_file";  fi
	if [[ -d "$ren_location" && "$(dirname "$source")/" == "$destination_folder" && "$item" != "$ren_file" ]]; then mv -f "$source" "$ren_temp_location"; rm -rf "$ren_location"; source="$ren_temp_location"; fi
	if [ "$item" != "$ren_file" ] && [ "$OS" == "darwin" ]; then mv -f "$source" "$ren_location" && sed -i '' "s;^$source_bis;$ren_location;g" "$log_file"
	elif [ "$item" != "$ren_file" ] && [ "$OS" != "darwin" ]; then mv -f "$source" "$ren_location" && sed -i "s;^$source_bis;$ren_location;g" "$log_file"
	fi
done
fi


## Cleanup filenames
if [[ "$has_display" == "yes" && "$clean_up_filenames" == "yes" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Cleaning up filenames";  fi
if [[ "$clean_up_filenames" == "yes" ]]; then for line in $(cat "$log_file"); do
	item=`echo "$(basename "$line")"`;
	ren_file=`echo "$item"`;
	source=`echo "$line"`;
	if [ -d "$source" ]; then extension="" && title_clean=`echo "$item"`; else extension=`echo "$item" | sed 's;.*\.;.;'` && title_clean=`echo "$item" | sed 's/\(.*\)\..*/\1/'`; fi
	title_clean_bis=`echo "$title_clean" | sed 's/\([\._]\)\([^ ]\)/ \2/g'`;
	title_clean_ter=`echo "$title_clean_bis" | sed "s/^/_/g" | sed "s/$/_/g" | sed "s/A/a/g" | sed "s/B/b/g" | sed "s/C/c/g" | sed "s/D/d/g" | sed "s/E/e/g" | sed "s/F/f/g" | sed "s/G/g/g" | sed "s/H/h/g" | sed "s/I/i/g" | sed "s/J/j/g" | sed "s/K/k/g" | sed "s/L/l/g" | sed "s/M/m/g" | sed "s/N/n/g" | sed "s/O/o/g" | sed "s/P/p/g" | sed "s/Q/q/g" | sed "s/R/r/g" | sed "s/S/s/g" | sed "s/T/t/g" | sed "s/U/u/g" | sed "s/V/v/g" | sed "s/W/w/g" | sed "s/X/x/g" | sed "s/Y/y/g" | sed "s/Z/z/g" | sed "s/[. _-]proper[. _-]/_/" | sed "s/[. _-]repack[. _-]/_/" | sed "s/\(.*\)[. _-]720p[. _-].*/\1 (720p)_/" | sed "s/\(.*\)[. _-]1080p[. _-].*/\1 (1080p)_/" | sed "s/\(.*\)[. _-]dvdr[. _-].*/\1 (DVDR)_/" | sed "s/\(.*\)[. _-]dvdrip[. _-].*/\1 (DVDRip)_/" | sed "s/\(.*\)[. _-]brrip[. _-].*/\1 (BDRip)_/" | sed "s/\(.*\)[. _-]bdrip[. _-].*/\1 (BDRip)_/" | sed "s/\(.*\)[. _-]r5[. _-].*/\1 (R5)_/" | sed "s/\(.*\)[. _-]dvdscr[. _-].*/\1 (DVDSCR)_/" | sed "s/\(.*\)[. _-]scr[. _-].*/\1 (SCR)_/" | sed "s/\(.*\)[. _-]ts[. _-].*/\1 (TS)_/" | sed "s/\(.*\)[. _-]workprint[. _-].*/\1 (WORKPRINT)_/" | sed "s/[. _-]pdtv[. _-].*/_/" | sed "s/[. _-]hdtv[. _-].*/_/" | sed "s/[. _-]xvid[. _-].*/_/" | sed "s/[. _-]webrip[. _-].*/_/" | sed "s/[. _-]web-dl[. _-].*/_/" | sed "s/\([. _-]\)\(mc\)*\(mac\)*a/\1\2\3A/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*b/\1\2\3B/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*c/\1\2\3C/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*d/\1\2\3D/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*e/\1\2\3E/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*f/\1\2\3F/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*g/\1\2\3G/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*h/\1\2\3H/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*i/\1\2\3I/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*j/\1\2\3J/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*k/\1\2\3K/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*l/\1\2\3L/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*m/\1\2\3M/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*n/\1\2\3N/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*o/\1\2\3O/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*p/\1\2\3P/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*q/\1\2\3Q/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*r/\1\2\3R/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*s/\1\2\3S/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*t/\1\2\3T/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*u/\1\2\3U/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*v/\1\2\3V/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*w/\1\2\3W/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*x/\1\2\3X/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*y/\1\2\3Y/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*z/\1\2\3Z/g" | sed "s/^_//g" | sed "s/_*$//g"`;
	if [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([sS])([0-9])([0-9])([eE])([0-9])([0-9])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] || [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([sS])([0-9])([0-9])([eE])([0-9])([0-9])")" && -d "$source" ]]; then
		series_title=`echo "$title_clean_ter" | sed 's;.\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;;'`;
		series_episode=`echo "$item" | sed 's;.*\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;S\2\3E\5\6;g'`;
		series_high_def=""
		if [ "$(echo "$item" | egrep -i "([7])([2])([0])([pP])")" ]; then series_high_def=`echo "$item" | sed 's;.*\([7]\)\([2]\)\([0]\)\([pP]\).*; \(\1\2\3p\);g'`;
		elif [ "$(echo "$item" | egrep -i "([1])([0])([8])([0])([pP])")" ]; then series_high_def=`echo "$item" | sed 's;.*\([1]\)\([0]\)\([8]\)\([0]\)\([pP]\).*; \(\1\2\3\4p\);g'`;
		fi
		is_repack=""
		if [[ "$repack_handling" == "yes" && "$(echo "$item" | egrep -i "([. _])repack([. _])|([. _])proper([. _])")" ]]; then is_repack=" REPACK"; fi
		ren_file=`echo "$series_title $series_episode$is_repack$series_high_def$extension"`;
	elif [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] || [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])")" && -d "$source" ]]; then
		talk_show_title=`echo "$title_clean_ter" | sed 's/\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\)/\1\2\3\4-\5\6-\7\8/g'`;
		ren_file=`echo "$talk_show_title$extension"`;
	elif [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "$movies_extensions_rev")" ]] || [[ "$clean_up_filenames" == "yes" && -d "$source" ]]; then
		ren_file=`echo "$title_clean_ter$extension"`;
	fi
	bis="_bis"
	ren_location=`echo "$(dirname "$source")/$ren_file"`;
	ren_temp_location=`echo "$(dirname "$source")/$ren_file$bis"`;
	source_bis=`echo "$line"`;
	if [ "$has_display" == "yes" ] && [ "$item" != "$ren_file" ]; then echo "- Renaming $item to $ren_file";  fi
	if [[ -d "$ren_location" && "$(dirname "$source")/" == "$destination_folder" && "$item" != "$ren_file" ]]; then mv -f "$source" "$ren_temp_location"; rm -rf "$ren_location"; source="$ren_temp_location"; fi
	if [ "$item" != "$ren_file" ] && [ "$OS" == "darwin" ]; then mv -f "$source" "$ren_location" && sed -i '' "s;^$source_bis;$ren_location;g" "$log_file"
	elif [ "$item" != "$ren_file" ] && [ "$OS" != "darwin" ]; then mv -f "$source" "$ren_location" && sed -i "s;^$source_bis;$ren_location;g" "$log_file"
	fi
done
fi

if [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" && "$OS" == "darwin" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" && "$OS" == "darwin" ]]; then sed -i '' '$d' "$log_file"
elif [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" && "$OS" != "darwin" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" && "$OS" != "darwin" ]]; then sed -i '$d' "$log_file"
fi


## Convert DTS track from MKV files to AC3
if [ "$has_display" == "yes" ] && [ "$dts_post" == "yes" ] && [ "$(cat "$log_file" | egrep -i "\.mkv$" )" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Converting DTS track to AC3";  fi
for line in $(cat "$log_file"); do
	if [ "$(echo "$line" | egrep -i "\.mkv$" )" ] && [ "$dts_post" == "yes" ]; then
		mkv=`echo "$line"`;
		if [ "$has_display" == "yes" ]; then "$mkvdts2ac3_bin" -w "$temp_folder" -k "$mkv" && rm -rf "$temp_folder"; fi
		if [ ! "$has_display" ]; then "$mkvdts2ac3_bin" -w "$temp_folder" -k "$mkv" && rm -rf "$temp_folder" > /dev/null 2>&1; fi
	fi
done

## Convert img disc images to iso disc images
if [ "$has_display" == "yes" ] && [ "$(echo "$line" | egrep -i "\.img$" )" ] && [ "$img_post" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Converting IMG disc image to ISO";  fi
for line in $(cat "$log_file"); do
	if [ "$(echo "$line" | egrep -i "\.img$" )" ] && [ "$img_post" == "yes" ]; then
		img=`echo "$line"`
		has_folder="$(if [ $(echo "$(dirname "$img")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		folder_short=`echo "$line" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
		img_file=`echo "$(basename "$line")"`
		new_folder=`echo "$destination_folder$folder_short/"`
		new_location=`echo "$destination_folder$folder_short/$img_file"`
		if [ "$has_folder" == "no" ]; then
			mkdir -p "$new_folder" && mv -f "$img" "$new_folder"
			if [ "$OS" == "darwin" ]; then sed -i '' "s;$img;$new_location;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$img;$new_location;g" "$log_file"; fi
			img=`echo "$new_location"`
		fi
		iso=`echo "$destination_folder$folder_short/$folder_short.iso"`
		if [ "$has_display" == "yes" ]; then echo "- Converting $img_file to an ISO";  fi
		if [ "$has_display" == "yes" ]; then "$ccd2iso_bin" "$img" "$iso"; else "$ccd2iso_bin" "$img" "$iso" > /dev/null 2>&1; fi
		iso_size="$(stat -c %s "$iso")"
		if [ "$iso_size" -lt 1000 ]; then
			if [ "$has_display" == "yes" ]; then echo "Actually $img_file is probably already an ISO";  fi
			rm -f "$iso" && cp -f "$img" "$iso"
		fi
		echo "$iso" >> "$log_file"
	fi
done


if [[ "$has_display" == "yes" && "$wii_post" == "yes" ]] || [[ "$has_display" == "yes" && "$tv_shows_post" != "no" ]] || [[ "$has_display" == "yes" && "$music_post" != "no" ]] || [[ "$has_display" == "yes" && "$movies_post" != "no" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Taking care of other optional features";  fi
for line in $(cat "$log_file"); do
	## Create a folder and a cuesheet for Wii backups
	if [ "$(echo "$line" | egrep -i "\.wii" )" ] && [ "$(echo "$line" | egrep -i "\.iso$" )" ] && [ "$wii_post" == "yes" ]; then
		wii=`echo "$line"`;
		has_folder="$(if [ $(echo "$(dirname "$wii")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		folder_short=`echo "$wii" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
		new_folder=`echo "$destination_folder$folder_short/"`
		iso_file=`echo "$(basename "$wii")"`
		dvd_file=`echo "$new_folder$folder_short.dvd"`
		new_iso_file_path=`echo "$destination_folder$folder_short/$iso_file"`
		if [ "$has_folder" == "no" ] && [ "$OS" == "darwin" ]; then
			mkdir -p "$new_folder" && mv -f "$wii" "$new_folder" && sed -i '' "s;$wii;$new_iso_file_path;g" "$log_file"
		elif [ "$has_folder" == "no" ] && [ "$OS" != "darwin" ]; then
			mkdir -p "$new_folder" && mv -f "$wii" "$new_folder" && sed -i "s;$wii;$new_iso_file_path;g" "$log_file"
		fi
		if [ "$has_display" == "yes" ]; then echo "- Creating a Cuesheet for $iso_file";  fi
		echo "$iso_file" > "$dvd_file"
		echo "$dvd_file" >> "$log_file"
	## Copy or move TV Shows to a specific folder	
	elif [ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" ] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [ "$tv_shows_post" == "copy" ]; then
		series_file=`echo "$line"`
		item=`echo "$(basename "$series_file")"`
		has_folder="$(if [ $(echo "$(dirname "$series_file")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		new_destination=`echo "$tv_shows_post_path$folder_short/"`
		if [ "$has_folder" == "no" ]; then
			if [ "$has_display" == "yes" ]; then echo "- Copying $item to your TV Shows Path";  fi
			cp -f "$series_file" "$tv_shows_post_path" && tv_show_post_perm="$tv_shows_post_path$(basename "$series_file")"
		else
			if [ "$has_display" == "yes" ]; then echo "- Copying $item to your TV Shows Path";  fi
			mkdir -p "$new_destination" && tv_show_post_dir_perm="$new_destination" && cp -f "$series_file" "$new_destination"
		fi
	elif [ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" ] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [ "$tv_shows_post" == "move" ]; then
		series_file=`echo "$line"`
		item=`echo "$(basename "$series_file")"`
		has_folder="$(if [ $(echo "$(dirname "$series_file")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		source_folder=`echo "$destination_folder$folder_short/"`
		new_destination=`echo "$tv_shows_post_path$folder_short/"`
		if [ "$has_folder" == "no" ]; then
			if [ "$has_display" == "yes" ]; then echo "- Moving $item to your TV Shows Path";  fi
			mv -f "$series_file" "$tv_shows_post_path" && tv_show_post_perm="$tv_shows_post_path$(basename "$series_file")" && if [ "$OS" == "darwin" ]; then sed -i '' "s;$series_file;$tv_shows_post_path$item;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$series_file;$tv_shows_post_path$item;g" "$log_file"; fi
		else
			if [ "$has_display" == "yes" ]; then echo "- Moving $item to your TV Shows Path";  fi
			tv_show_post_dir_perm="$new_destination" && mkdir -p "$new_destination" && mv -f "$series_file" "$new_destination" && if [ "$OS" == "darwin" ]; then sed -i '' "s;$source_folder;$new_destination;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$source_folder;$new_destination;g" "$log_file"; fi
		fi
	## Copy Music files to a specific folder	
	elif [ "$(echo "$line" | egrep -i "$music_extensions_rev" )" ] && [ "$music_post" == "copy" ]; then
		music_file=`echo "$line"`
		item=`echo "$(basename "$music_file")"`
		has_folder="$(if [ $(echo "$(dirname "$music_file")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		new_destination=`echo "$music_post_path$folder_short/"`
		if [ "$has_folder" == "no" ]; then
			if [ "$has_display" == "yes" ]; then echo "- Copying $item to your Music Path";  fi
			cp -f "$music_file" "$music_post_path" && music_post_perm="$music_post_path$(basename "$music_file")"
		else
			if [ "$has_display" == "yes" ]; then echo "- Copying $item to your Music Path";  fi
			mkdir -p "$new_destination" && music_post_dir_perm="$new_destination" && cp -f "$music_file" "$new_destination"
		fi
	elif [ "$(echo "$line" | egrep -i "$music_extensions_rev" )" ] && [ "$music_post" == "move" ]; then
		music_file=`echo "$line"`
		item=`echo "$(basename "$music_file")"`
		has_folder="$(if [ $(echo "$(dirname "$music_file")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		source_folder=`echo "$destination_folder$folder_short/"`
		new_destination=`echo "$music_post_path$folder_short/"`
		if [ "$has_folder" == "no" ]; then
			if [ "$has_display" == "yes" ]; then echo "- Moving $item to your Music Path";  fi
			mv -f "$music_file" "$music_post_path" && music_post_perm="$music_post_path$(basename "$music_file")" && if [ "$OS" == "darwin" ]; then sed -i '' "s;$music_file;$music_post_path$item;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$music_file;$music_post_path$item;g" "$log_file"; fi
		else
			if [ "$has_display" == "yes" ]; then echo "- Moving $item to your Music Path";  fi
			music_post_dir_perm="$new_destination" && mkdir -p "$new_destination" && mv -f "$music_file" "$new_destination" && if [ "$OS" == "darwin" ]; then sed -i '' "s;$source_folder;$new_destination;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$source_folder;$new_destination;g" "$log_file"; fi
		fi
	## Copy movies to a specific folder	
	elif [ "$(echo "$line" | egrep -i "$movies_detect_patterns_rev" )" ] && [ "$(echo "$line" | egrep -i "$movies_extensions_rev" )" ] && [ "$movies_post" == "copy" ]; then
		movie_file=`echo "$line"`
		item=`echo "$(basename "$movie_file")"`
		has_folder="$(if [ $(echo "$(dirname "$movie_file")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		new_destination=`echo "$movies_post_path$folder_short/"`
		if [ "$has_folder" == "no" ]; then
			if [ "$has_display" == "yes" ]; then echo "- Copying $item to your Movies Path";  fi
			cp -f "$movie_file" "$movies_post_path" && movies_post_perm="$movies_post_path$(basename "$movie_file")"
		else
			if [ "$has_display" == "yes" ]; then echo "- Copying $item to your Movies Path";  fi
			mkdir -p "$new_destination" && movies_post_dir_perm=`echo "$new_destination"` && cp -f "$movie_file" "$new_destination"
		fi
	elif [ "$(echo "$line" | egrep -i "$movies_detect_patterns_rev" )" ] && [ "$(echo "$line" | egrep -i "$movies_extensions_rev" )" ] && [ "$movies_post" == "move" ]; then
		movie_file=`echo "$line"`
		item=`echo "$(basename "$movie_file")"`
		has_folder="$(if [ $(echo "$(dirname "$movie_file")/") == "$destination_folder" ]; then echo "no"; else echo "yes"; fi)"
		source_folder=`echo "$destination_folder$folder_short/"`
		new_destination=`echo "$movies_post_path$folder_short/"`
		if [ "$has_folder" == "no" ]; then
			if [ "$has_display" == "yes" ]; then echo "- Moving $item to your Movies Path";  fi
			mv -f "$movie_file" "$movies_post_path" && movies_post_perm="$movies_post_path$(basename "$movie_file")" && if [ "$OS" == "darwin" ]; then sed -i '' "s;$movie_file;$movies_post_path$item;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$movie_file;$movies_post_path$item;g" "$log_file"; fi
		else
			if [ "$has_display" == "yes" ]; then echo "- Moving $item to your Movies Path";  fi
			movies_post_dir_perm="$new_destination" && mkdir -p "$new_destination" &&  mv -f "$movie_file" "$new_destination" && if [ "$OS" == "darwin" ]; then sed -i '' "s;$source_folder;$new_destination;g" "$log_file"; elif [ "$OS" != "darwin" ]; then sed -i "s;$source_folder;$new_destination;g" "$log_file"; fi
		fi
	fi
done
if [ -d "$folder_short" ] || [ -L "$folder_short" ]; then files_in_folder_short=$(ls -1 "$destination_folder$folder_short"|wc -l); fi
if [[ "$music_post" == "move" && $files_in_folder_short -eq 0 ]] || [[ "$tv_shows_post" == "move" && $files_in_folder_short -eq 0 ]] || [[ "$movies_post" == "move" && $files_in_folder_short -eq 0 ]]; then
	rm -rf "$destination_folder$folder_short"
	folder_short_deleted="yes"
fi


## Use a source / destination log shared with a third party app - Add path to enable
count=0 && files=$(( $count + $(cat "$log_file"|wc -l) ))
if [[ $files -eq 1 ]] && [ "$third_party_log" != "no" ]; then echo "$(cat "$log_file")" > "$third_party_log"; fi
if [[ $files -gt 1 ]] && [ "$third_party_log" != "no" ]; then folder_name=`echo "$destination_folder$folder_short"`; echo "$folder_name" > "$third_party_log"; fi
if [ "$third_party_log" != "no" ] && [ "$user_perm_post" == "yes" ]; then chown "$user_perm_post":"$group_perm_post" "$third_party_log" && sudo chmod "$files_perm_post" "$third_party_log"; fi


## Edit files and folders permissions - Still quick and dirty
if [[ "$has_display" == "yes" && "$user_perm_post" != "no" ]] || [[ "$has_display" == "yes" && "$files_perm_post" != "no" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Setting permissions";  fi
if [ "$music_post_perm" ]; then echo "$music_post_perm" >> "$log_file"; fi
if [ "$tv_show_post_perm" ]; then echo "$tv_show_post_perm" >> "$log_file"; fi
if [ "$movies_post_perm" ]; then echo "$movies_post_perm" >> "$log_file"; fi
if [ "$folder_short" ] && [ "$folder_short_deleted" != "yes" ]; then echo "$destination_folder$folder_short" >> "$log_file"; fi
if [ "$music_post_dir_perm" ] && [ "$music_post" != "move" ]; then echo "$music_post_dir_perm" >> "$log_file" && ls -f -1 "$music_post_dir_perm"*.* >> "$log_file"; fi
if [ "$tv_show_post_dir_perm" ] && [ "$tv_shows_post" != "move" ]; then echo "$tv_show_post_dir_perm" >> "$log_file" && ls -f -1 "$tv_show_post_dir_perm"*.* >> "$log_file"; fi
if [ "$movies_post_dir_perm" ] && [ "$movies_post" != "move" ]; then echo "$movies_post_dir_perm" >> "$log_file" && ls -f -1 "$movies_post_dir_perm"*.* >> "$log_file"; fi

for line in $(cat "$log_file"); do
	if [[ "$user_perm_post" != "no" && "$group_perm_post" != "no" ]] || [[ "$files_perm_post" != "no" && "$folder_perm_post" != "no" ]]; then
		item=`echo "$line"`
		if [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && "$has_display" == "yes" ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && "$has_display" == "yes" ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chown "$user_perm_post":"$group_perm_post" "$item"; fi
		if [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && "$has_display" == "yes" ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chmod "$files_perm_post" "$item"; fi
		if [[ -f "$item" && "$edit_perm_as_sudo" == "no" && "$files_perm_post" != "no" ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "no" && "$files_perm_post" != "no" ]]; then chmod "$files_perm_post" "$item"; fi
		if [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && "$has_display" == "yes" ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chmod "$folder_perm_post" "$item"; fi
		if [[ -d "$item" && "$edit_perm_as_sudo" == "no" && "$folder_perm_post" != "no" ]] || [[ -L "$item" && "$edit_perm_as_sudo" == "no" && "$folder_perm_post" != "no" ]]; then chmod "$folder_perm_post" "$item"; fi
	fi
done


## Reset timestamp (mtime)
if [ "$has_display" == "yes" ] && [ "$reset_timestamp" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Resetting mtime";  fi
for line in $(cat "$log_file"); do
	if [ "$reset_timestamp" == "yes" ]; then
		item=`echo "$line"`
		touch "$line"
	fi
done


## Delete third party log if required
if [ "$delete_third_party_log" == "yes" ] && [ "$third_party_log" != "no" ]; then rm -f "$third_party_log"; fi

##################################################################################

## Restore running environment
export TR_TORRENT_DIR=""
export TR_TORRENT_NAME=""
export torrent=""
rm -f "$log_file"

if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" != "no" && -d "$subtitles_directory" && "$(find "$subtitles_directory" -maxdepth 1 -not -name "._*" -name "*.srt" -type f)" ]]; then
 	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Fetching new subtitles from the subtitles folder";  fi
 	export subtitles_mode="yes"
 	has_display="no"
 	for line in $(find "$subtitles_directory" -maxdepth 1 -not -name "._*" -name "*.srt" -type f); do
 		line=`echo "$line"`
 		item=`echo "$(basename "$line")"`
 		item_bis=`echo "$item" | sed 's/\(.*\)\..*/\1/'`
 		orig_file=`echo "$(find "$subtitles_directory" -name "$item_bis.*" -type f | egrep -i "\.avi$|\.mkv$|\.divx$")"`
 		new_line=`echo "$(cat "$orig_file" | sed '/^ *$/d' | sed 's/\(.*\)\..*/\1\.srt/')"`
 		if [ "$line" != "$new_line" ]; then mv "$line" "$new_line"; fi
 		"$script_path/torrentexpander.sh" "$new_line" "$destination_folder"
 		rm -f "$new_line"
 		rm -f "$orig_file"
 		find "$subtitles_directory" -mtime +30 -exec rm -f {} \;
 	done
 	if [ -t 1 ]; then echo "That's All Folks"; fi
fi

if [ "$has_display" == "yes" ]; then echo "That's All Folks";  fi

export subtitles_mode=""
IFS=$SAVEIFS

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   