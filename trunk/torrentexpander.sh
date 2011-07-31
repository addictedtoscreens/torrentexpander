#!/bin/bash

## Set up the running environment
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

## Define some variables
if [ -f "$1" ] || [ -d "$1" ]; then torrent="$1"; fi
if [ -d "$2" ]; then alt_dest_enabled="yes" && alt_destination="$2"; fi

if [ -t 1 ] && [ "$subtitles_mode" != "yes" ]; then has_display="yes"; fi
if [ "$1" == "-c" ]; then first_run="yes"; fi

nice -n 15 echo > /dev/null 2>&1 && if [ "$?" == "0" ]; then nice_available="yes"; fi
find -L / -maxdepth 1 > /dev/null 2>&1 && if [ "$?" == "0" ]; then find_l_available="yes"; fi


##################################################################################
##                   TORRENTEXPANDER 
##                   v0.17
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
## I recommend using a different folder from the one where your torrents are located
##ÊA sub directory of your torrents directory is fine though.
## If you really want to extract your torrents in-place and delete the
## original torrent, switch destructive_mode to yes
destination_folder="/path/to/your/destination/folder/"
destructive_mode="no"
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
movies_detect_patterns="TS,TVRip,DVDSCR,R5,DVDRip,BDRip,BRRip,DVDR,720p,1080p"
movies_detect_patterns_pt_2="Workprint,SCR"
other_movies_patterns="proper,repack,rerip,pdtv,hdtv,xvid,webrip,web-dl,readnfo,ntsc,pal"
####################### Optional functionalities variables #######################
#################### Set these variables to "no" to disable ######################
## Fix numbering for TV Shows - Switch variable to "yes" to enable
tv_shows_fix_numbering="yes"
## Cleanup Filenames - Switch variable to "yes" to enable
clean_up_filenames="yes"
## Keep a dummy video file with the original filename for subtitles retrieval
subtitles_handling="no"
## Repack handling - Switch variable to "yes" to enable
repack_handling="no"
## Create Wii Cuesheet - Switch variable to "yes" to enable
wii_post="no"
## Convert img to iso - Switch variable to "yes" to enable
img_post="no"
## Copy or move TV Shows to a specific folder - choose action (copy / move)
## and add path to enable.
## Using tv_shows_post_path_mode, series files can also be sorted by /Series/Episode (s)
## or /Series/Season X/Episode (ss) or /Series/Season XX/Episode (sss)
tv_shows_post="no"
tv_shows_post_path="no"
tv_shows_post_path_mode="no"
## Copy or move movies to a specific folder - choose action (copy / move)
## and add path to enable
movies_post="no"
movies_post_path="no"
## Copy or move music to a specific folder - choose action (copy / move)
## and add path to enable
music_post="no"
music_post_path="no"
## Convert DTS track from MKV files to AC3 - Check mkvdts2ac3.sh path and switch variable to "yes" to enable
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

sed -i "s;^this_string_should_not_be_there$;^$;g" "$settings_file" > /dev/null 2>&1; if [ "$?" == "0" ]; then gnu_sed_available="yes"; fi

check_settings=$(echo "$(cat "$settings_file")")

## Trying to guess default paths
if [[ "$check_settings" != *estination_folder=* || "$check_settings" == *estination_folder=incorrect_or_not_se* ]]; then
	# This line should work on most unix systems
	if [ ! -d "$destination_folder" ] && [ -d "$HOME/Desktop" ]; then destination_folder="$HOME/Desktop"; fi
	# This line is for ubuntu systems when the desktop has a language specific name
	if [ ! -d "$destination_folder" ]; then xdg-user-dir > /dev/null 2>&1 && if [ "$?" == "0" ]; then destination_folder="$(xdg-user-dir DESKTOP)"; fi; fi
	# This line is for PopCornHour media players
	if [ ! -d "$destination_folder" ] && [ -d "/share/Downloads" ]; then destination_folder="/share/Video/"; fi
fi
if [[ "$check_settings" != *nrar_bin=* || "$check_settings" == *nrar_bin=incorrect_or_not_se* ]]; then
	# Looking for unrar in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
	if [ ! -x "$unrar_bin" ] && [ -x "$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unrar; fi; done | sed -n -e '1p')" ]; then unrar_bin="$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unrar; fi; done | sed -n -e '1p')"; fi
	# If unrar is unavailable, switch back to 7z
	if [ ! -x "$unrar_bin" ] && [ -x "$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')" ]; then unrar_bin="$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')"; fi
fi
if [[ "$check_settings" != *nzip_bin=* || "$check_settings" == *nzip_bin=incorrect_or_not_se* ]]; then
	# Looking for unrar in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
	if [ ! -x "$unzip_bin" ] && [ -x "$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unzip; fi; done | sed -n -e '1p')" ]; then unzip_bin="$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unzip; fi; done | sed -n -e '1p')"; fi
	# If unzip is unavailable, switch back to 7z
	if [ ! -x "$unzip_bin" ] && [ -x "$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')" ]; then unzip_bin="$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/Applications\n/nmt/apps\n/usr/local/bin"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')"; fi
fi
if [[ "$check_settings" != *cd2iso_bin=* || "$check_settings" == *cd2iso_bin=incorrect_or_not_se* ]]; then
	if [ ! -x "$ccd2iso_bin" ] && [ -x "$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/nmt/apps\n/Applications"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name ccd2iso; fi; done | sed -n -e '1p')" ]; then ccd2iso_bin="$(for d in $(echo -e "$(echo -e "$PATH" | sed "s;:;\\\n;g")\n/nmt/apps\n/Applications"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name ccd2iso; fi; done | sed -n -e '1p')"; fi
fi

## Inserting values into the settings file
for c in $(echo -e "unrar_bin\nunzip_bin\nccd2iso_bin\nmkvdts2ac3_bin"); do
	pat="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=\*;")"
	pat_two="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=incorrect_or_not_se\*;")"
	if [[ "$check_settings" != $pat && -x "${!c}" ]] || [[ "$check_settings" == $pat_two && -x "${!c}" ]]; then
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/$c=/d" "$settings_file"; fi;
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" == "yes" ]]; then sed -i "/$c=/d" "$settings_file"; fi;
		echo "$c=${!c}" >> "$settings_file"
	elif [[ "$check_settings" != $pat ]]; then echo "$c=incorrect_or_not_set" >> "$settings_file"
	fi
done
for c in $(echo -e "destination_folder\ntv_shows_post_path\nmovies_post_path\nmusic_post_path"); do
	pat="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=\*;")"
	pat_two="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=n\*;")"
	if [[ "$check_settings" != $pat && -d "${!c}" ]] || [[ "$check_settings" == $pat_two && -d "${!c}" ]]; then
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/$c=/d" "$settings_file"; fi;
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" == "yes" ]]; then sed -i "/$c=/d" "$settings_file"; fi;
		echo "$c=${!c}" >> "$settings_file"
	elif [[ "$check_settings" != $pat ]]; then echo "$c=no" >> "$settings_file"
	fi
done
if [ "$third_party_log" != "no" ]; then third_party_log_directory="$(echo "$(dirname "$third_party_log")")"; fi
if [[ "$check_settings" != *hird_party_log=* && -d "$third_party_log_directory" ]] || [[ "$check_settings" == *hird_party_log=n* && -d "$third_party_log_directory" ]]; then
	if [[ "$check_settings" == *hird_party_log=n* && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/third_party_log=/d" "$settings_file"; fi;
	if [[ "$check_settings" == *hird_party_log=n* && "$gnu_sed_available" == "yes" ]]; then sed -i "/third_party_log=/d" "$settings_file"; fi;
	echo "third_party_log="$third_party_log"" >> "$settings_file";
elif [[ "$check_settings" != *hird_party_log=* ]]; then echo "third_party_log=no" >> "$settings_file"
fi
for c in $(echo -e "destructive_mode\ntv_shows_fix_numbering\nclean_up_filenames\nsubtitles_handling\nrepack_handling\nwii_post\nimg_post\ntv_shows_post\ntv_shows_post_path_mode\nmovies_post\nmusic_post\ndts_post\nuser_perm_post\ngroup_perm_post\nfiles_perm_post\nfolder_perm_post\nedit_perm_as_sudo\nreset_timestamp\nsupported_extensions\ntv_show_extensions\nmovies_extensions\nmusic_extensions"); do
	pat="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=\*;")"
	if [[ "$check_settings" != $pat ]]; then echo "$c=${!c}" >> "$settings_file"; fi
done

# Removing patterns from settings file generated by a previous version of the script
if [[ "$check_settings" == *ovies_detect_patterns=* && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/movies_detect_patterns=/d" "$settings_file"; fi
if [[ "$check_settings" == *ovies_detect_patterns=* && "$gnu_sed_available" == "yes" ]]; then sed -i "/movies_detect_patterns=/d" "$settings_file"; fi

# Escaping spaces from paths in settings file
if [ "$(echo "$check_settings" | egrep -i "([^\\]) ")" ] && [ "$gnu_sed_available" != "yes" ]; then sed -i '' 's;\([^\\]\) ;\1\\ ;g' "$settings_file"; fi
if [ "$(echo "$check_settings" | egrep -i "([^\\]) ")" ] && [ "$gnu_sed_available" == "yes" ]; then sed -i 's;\([^\\]\) ;\1\\ ;g' "$settings_file"; fi

source "$settings_file"

if [ "$movies_detect_patterns_override" ]; then movies_detect_patterns="$movies_detect_patterns_override"; fi
if [ "$movies_detect_patterns_pt_2_override" ]; then movies_detect_patterns_pt_2="$movies_detect_patterns_pt_2_override"; fi
if [ "$other_movies_patterns_override" ]; then other_movies_patterns="$other_movies_patterns_override"; fi
if [[ "$tv_shows_post_path" != */ ]] && [ "$tv_shows_post" != "no" ]; then tv_shows_post_path="$tv_shows_post_path/"; fi
if [[ "$music_post_path" != */ ]] && [ "$music_post_path" != "no" ]; then music_post_path="$music_post_path/"; fi
if [[ "$movies_post_path" != */ ]] && [ "$movies_post_path" != "no" ]; then movies_post_path="$movies_post_path/"; fi
supported_extensions_rev="\.$(echo $supported_extensions | sed 's;,;\$\|\\\.;g')$"
tv_show_extensions_rev="\.$(echo $tv_show_extensions | sed 's;,;\$\|\\\.;g')$"
movies_extensions_rev="\.$(echo $movies_extensions | sed 's;,;\$\|\\\.;g')$"
music_extensions_rev="\.$(echo $music_extensions | sed 's;,;\$\|\\\.;g')$"
movies_detect_patterns_rev="[^[:alnum:]]$(echo $movies_detect_patterns | sed 's;,;[^[:alnum:]]|[^[:alnum:]];g')[^[:alnum:]]"
movies_detect_patterns_pt_2_rev="[^[:alnum:]]$(echo $movies_detect_patterns_pt_2 | sed 's;,;[^[:alnum:]]|[^[:alnum:]];g')[^[:alnum:]]"

##################################################################################
############################### Setup Assistant ##################################
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then echo -e "----------------------------------------------------\n----------------------------------------------------\n\nWELCOME TO TORRENTEXPANDER\n\n----------------------------------------------------\n----------------------------------------------------\n\n"; fi
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then echo -e "This is the first time you're running this script\nA few settings are required for it to run\nThese required settings are :\n- The destination_folder -> This is where the content of your torrents will be expanded / copied\n- unrar_bin -> This is the path to the Unrar binary. If it's not already installed on your computer then Google is your friend\n- unzip_bin -> This is the path to the Unrar binary. It's probably already installed on your computer\n\nAll other options are already set to their default value\nIf you want more details about those options, open this script with a text editor\n\nA nano editor will now open so that you can edit your settings\nTo save them you'll have to press Control-X then Y then Enter\n\nOnce you're ready press Enter" && read -p ""; fi
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then nano "$settings_file" && echo -e "\n\nYou're done with your setup\nThis script will exit now\nIf you need to edit your settings again just run $script_path/torrentexpander.sh -c" && exit; fi

##################################################################################
###################### Kinda graphical user interface ############################
if [[ "$has_display" == "yes" && ! "$torrent" ]] || [[ "$has_display" == "yes" && ! "$alt_dest_enabled" ]]; then echo -e "----------------------------------------------------\n----------------------------------------------------\n\nWELCOME TO TORRENTEXPANDER\n\n----------------------------------------------------\n----------------------------------------------------\n\n"; fi

## Trying to find out transmission download-dir from transmission settings file
transmission_settings_file="$(if [ -f "/share/.transmission/settings.json" ]; then echo "/share/.transmission/settings.json"; elif [ -f "$HOME/.config/transmission/settings.json" ]; then echo "$HOME/.config/transmission/settings.json"; fi)"
if [ "$has_display" == "yes" ] && [ -f "$transmission_settings_file" ] && [ ! "$torrent" ]; then cd "$(echo "$(sed -n '/"download-dir": /p' "$transmission_settings_file")" | sed -e 's/    "download-dir": "//g' -e 's/", //g')"; elif [ "$has_display" == "yes" ] && [ ! -f "$transmission_settings_file" ] && [ ! "$torrent" ]; then cd "$HOME"; fi

## Asking the User for the torrent source
selected=0
item_selected=""
if [ "$has_display" == "yes" ] && [ ! "$torrent" ]; then
	while [[ $selected -eq 0 ]] ; do
		count=-1 && echo "Select Torrent Source :" && echo "" && echo "$(pwd)" && echo ""
		for item in $(echo -e "Select current folder\n..\n$(ls -1)"); do
			count=$(( $count + 1 )); var_name="sel$count"; var_val="$item"; eval ${var_name}=`echo -ne \""${var_val}"\"`; echo "$count - $item"
		done
		echo "" && echo "Type the ID of the Torrent Source :"
		read answer && sel_item="$(echo "sel$answer")"
		item_selected=${!sel_item}
		if [ "$item_selected" == "Select current folder" ]; then item_selected="$(pwd)" && selected=1
		elif [ "$item_selected" == ".." ]; then cd "$(dirname $(pwd))"
		elif [[ "$(pwd)" == "/" && -d "/$item_selected" ]]; then cd "/$item_selected"
		elif [ -d "$(pwd)/$item_selected" ]; then cd "$(pwd)/$item_selected"
		elif [ -f "$(pwd)/$item_selected" ]; then item_selected="$(pwd)/$item_selected" && selected=1
		fi
		echo ""
	done
fi
if [ "$has_display" == "yes" ] && [ ! "$torrent" ] && [ "$item_selected" ] && [[ $selected -eq 1 ]]; then torrent="$item_selected" && echo "" && echo "Your File Source is $torrent" && echo "" && echo ""; fi

## Asking the User for the torrent destination - A default destination can be set by inserting a gui_transmission_destination in the settings file
if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ] && [ "$gui_transmission_destination" ]; then cd "$gui_transmission_destination"; elif [[ "$has_display" == "yes" && ! "$alt_dest_enabled" && ! "$alt_destination" && -d "$destination_folder" ]]; then cd "$destination_folder"; elif [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ]; then cd "$HOME"; fi
selected=0
item_selected=""
if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ]; then
	while [[ $selected -eq 0 ]] ; do
		count=-1 && echo "" && echo "Select Destination Folder :" && echo "" && echo "$(pwd)" && echo ""
		for item in $(echo -e "Select current folder\n..\n$(ls -1)"); do
			count=$(( $count + 1 )); var_name="sel$count"; var_val="$item"; eval ${var_name}=`echo -ne \""${var_val}"\"`; echo "$count  -  $item"
		done
		echo "" && echo "Type the ID of the Destination Folder :"
		read answer && sel_item="$(echo "sel$answer")"
		item_selected=${!sel_item}
		if [ "$item_selected" == "Select current folder" ]; then item_selected="$(pwd)" && selected=1
		elif [ "$item_selected" == ".." ]; then cd "$(dirname $(pwd))"
		elif [[ "$(pwd)" == "/" && -d "/$item_selected" ]]; then cd "/$item_selected"
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
temp_folder_without_slash="$(echo "$destination_folder$torrentexpander_temp")"

##################################################################################
############################# TORRENT SOURCE SETUP ###############################
################# You probably dont need to do anything here #####################
## This script will use a variable named torrent if file, else cd variable torrent, 
## else use transmission variables if file, else cd transmission variables,
## else use current folder
if [ "$TR_TORRENT_NAME" ] && [ ! "$torrent" ]; then torrent="$TR_TORRENT_DIR/$TR_TORRENT_NAME"; fi
if [ -f "$torrent" ] || [ -d "$torrent" ]; then
	delete_third_party_log="yes"
	if [ -d "$torrent" ]; then cd "$torrent" && current_folder=`echo "$(pwd)"` && folder_short=`echo "$( basename "$(pwd)" )"` && torrent=""; fi
elif [ "$third_party_log" != "no" ] && [ -f "$third_party_log" ]; then
	torrent="$(cat "$third_party_log")"
	if [ -d "$torrent" ]; then cd "$torrent" && current_folder=`echo "$(pwd)"` && folder_short=`echo "$( basename "$(pwd)" )"` && torrent=""; fi
elif [ "$has_display" == "yes" ]; then
	echo "I cannot detect any Torrent Source - This script will exit" && exit
else exit
fi
######################### END TORRENT SOURCE SETUP ###############################
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

if [ ! -d "$destination_folder" ]; then echo "Your destination folder is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your destination folder is incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ ! -d "$temp_directory" ]; then echo "Your temp folder path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your temp folder path is incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ ! -d "$tv_shows_post_path" ] && [ "$tv_shows_post" != "no" ]; then	echo "Your TV Shows path is incorrect - TV Shows Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your TV Shows path is incorrect - TV Shows Post will be disabled"; fi; tv_shows_post="no"; fi
if [ ! -d "$music_post_path" ] && [ "$music_post" != "no" ]; then echo "Your music path is incorrect - Music Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your music path is incorrect - Music Post will be disabled"; fi; music_post="no"; fi
if [ ! -d "$movies_post_path" ] && [ "$movies_post" != "no" ]; then	echo "Your movies path is incorrect - Movies Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your movies path is incorrect - Movies Post will be disabled"; fi; movies_post="no"; fi
if [ ! -d "$third_party_log_directory" ] && [ "$third_party_log" != "no" ]; then echo "Your third party log path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your third party log path is incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ -d "$temp_folder" ]; then echo "Temp folder already exists. Please delete it or edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Temp folder already exists. Please delete it or edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ "$torrent_directory" == "$destination_folder" ] && [ "$destructive_mode" != "yes" ]; then echo "Your destination folder should be different from the one where your torrent is located. Please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your destination folder should be different from the one where your torrent is located. Please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ ! -x "$unrar_bin" ]; then echo "Your Unrar path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your Unrar path is incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ ! -x "$unzip_bin" ]; then echo "Your Unzip path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your Unzip path is incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ ! -x "$mkvdts2ac3_bin" ] && [ "$dts_post" == "yes" ]; then echo "Path to mkvdts2ac3.sh is incorrect - DTS Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Path to mkvdts2ac3.sh is incorrect - DTS Post will be disabled"; fi; dts_post="no"; fi
if [ ! -x "$ccd2iso_bin" ] && [ "$img_post" == "yes" ]; then echo "Path to ccd2iso is incorrect - IMG to ISO Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Path to ccd2iso is incorrect - IMG to ISO Post will be disabled"; fi; img_post="no"; fi
if [[ "$supported_extensions_rev" =~ rar ]] || [[ "$tv_show_extensions_rev" =~ rar ]] || [[ "$movies_extensions_rev" =~ rar ]] || [[ "$music_extensions_rev" =~ rar ]] || [[ "$supported_extensions_rev" =~ zip ]] || [[ "$tv_show_extensions_rev" =~ zip ]] || [[ "$movies_extensions_rev" =~ zip ]] || [[ "$music_extensions_rev" =~ zip ]]; then echo "Your supported file extensions are incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your supported file extensions are incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [[ "$third_party_log" != "no" && -f "$third_party_log" ]] || [ "$alt_dest_enabled" == "yes" ]; then if [ "$tv_shows_post" != "no" ]; then tv_shows_post="copy"; fi; if [ "$music_post" != "no" ]; then music_post="copy"; fi; if [ "$movies_post" != "no" ]; then movies_post="copy"; fi; fi
if [ "$quit_on_error" == "yes" ]; then if [ "$has_display" == "yes" ]; then echo -e "\n\nThere's something wrong with your settings. Please review them now." && read -p "" && nano "$settings_file" && echo -e "\n\nYou're done with your setup\nThis script will exit now\nIf you need to edit your settings again just run $script_path/torrentexpander.sh -c"; fi; exit; fi

##################################################################################


##################### CHECKING IF SCRIPT IS ALREADY RUNNING ######################
script_notif="torrentexpander is running"
log_file="$(echo "$destination_folder$script_notif")"

count=0
while [ -f "$log_file" ]; do
	if [ "$has_display" == "yes" ]; then echo "Waiting for another instance of the script to end . . . . . ."; fi
	sleep 15; count=$(( count + 1 )); if [[ $count -gt 3600 ]]; then rm "$log_file" && exit; fi
done

if [ ! -f "$log_file" ]; then
	touch "$log_file"
fi
##################################################################################


step_number=0
mkdir -p "$temp_folder"

## Expanding and copying folders to the temp folder
if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Expanding / moving content of the torrent";  fi
for item in $(if [[ "$current_folder" && "$find_l_available" == "yes" ]]; then find -L "$current_folder" -type d; elif [ "$current_folder" ]; then find "$current_folder" -type d; else [ "$torrent" ]; echo "$torrent"; fi); do
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	elif [[ "$(ls "$item" | egrep -i "\.rar$|\.001$")" ]]; then
		if [[ "$(ls "$item" | egrep -i "part001\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part001\.rar$"` && searchPath="$item/$rarFile";
		elif [[ "$(ls "$item" | egrep -i "part01\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part01\.rar$"` && searchPath="$item/$rarFile";
		elif [[ -d "$item" && "$(ls "$item" | egrep -i "\.rar$")" ]]; then searchPath=`find -L "$item" -maxdepth 1 ! -name "._*" -type f | egrep -i "\.rar$"`;
		elif [[ "$(echo "$torrent" | egrep -i "\.rar$" )" ]]; then searchPath=`echo "$item" | egrep -i "\.rar$"`;
		elif [[ "$(ls "$item" | egrep -i "\.001$")" ]]; then rarFile=`ls "$item" | egrep -i "\.001$"` && searchPath="$item/$rarFile";
		fi
		if [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder"; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder" ; done
		elif [[ "$unrar_bin" == *unrar* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 "$unrar_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 "$unrar_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unrar_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		fi
	fi
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	elif [[ "$(ls $item | egrep -i "\.zip$")" ]]; then
		if [[ -d "$item" && "$(ls "$item" | egrep -i "\.zip$")" ]]; then searchPath=`find -L "$item" -maxdepth 1 ! -name "._*" -type f | egrep -i "\.zip$"`;
		elif [[ "$(echo "$item" | egrep -i "\.zip$" )" ]]; then searchPath=`echo "$item" | egrep -i "\.zip$"`;
		fi
		if [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o `echo "$f"` -d "$temp_folder"; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o `echo "$f"` -d "$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o `echo "$f"` -d "$temp_folder"; done
		elif [[ "$unzip_bin" == *unzip* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o `echo "$f"` -d "$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unzip_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		fi
	fi
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	elif [[ "$(ls $item | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$")" ]]; then
		if [[ -d "$item" && "$(ls "$item" | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$")" && "$find_l_available" == "yes" ]]; then otherFiles=`find -L "$item" -maxdepth 1 ! -name "._*" -type f | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$"` && dest_path=`echo "$item/" | sed "s;$current_folder/;$temp_folder;g"`
		elif [[ -d "$item" && "$(ls "$item" | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$")" ]]; then otherFiles=`find "$item" -maxdepth 1 ! -name "._*" -type f | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$"` && dest_path=`echo "$item/" | sed "s;$current_folder/;$temp_folder;g"`
		elif [[ "$(echo "$item" | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$")" ]]; then otherFiles=`echo "$item" | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$"` && dest_path=`echo "$temp_folder"`
		fi
		if [[ "$nice_available" == "yes" && "$destructive_mode" != "yes" ]]; then for f in $(echo -e "$otherFiles"); do otherFile=`echo "$f"`; mkdir -p "$dest_path"; nice -n 15 cp -f "$otherFile" "$dest_path"; done
		elif [[ "$nice_available" != "yes" && "$destructive_mode" != "yes" ]]; then for f in $(echo -e "$otherFiles"); do otherFile=`echo "$f"`; mkdir -p "$dest_path"; cp -f "$otherFile" "$dest_path"; done
		elif [ "$destructive_mode" == "yes" ]; then for f in $(echo -e "$otherFiles"); do otherFile=`echo "$f"`; mkdir -p "$dest_path"; nice -n 15 mv -f "$otherFile" "$dest_path"; done
		fi
	fi
done

## If destructive_mode is enabled, remove original torrent
cd "$destination_folder"
if [[ "$has_display" == "yes" && "$destructive_mode" == "yes" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Deleting original torrent";  fi
if [[ "$destructive_mode" == "yes" && "$current_folder" ]]; then rm -rf "$current_folder"; elif [[ "$destructive_mode" == "yes" && "$torrent" && -f "$torrent" ]]; then rm -f "$torrent"; fi

## If archives within archives - Expanding and copying folders to the temp folder
for item in $(find "$temp_folder_without_slash" -type d); do
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	elif [[ "$(ls "$item" | egrep -i "\.rar$")" ]]; then
		searchPath=`find -L "$item" -maxdepth 1 ! -name "._*" -type f | egrep -i "\.rar$"`;
		if [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item"; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item"; done
		elif [[ "$unrar_bin" == *unrar* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 `echo "$f"` x -y "$searchPath" -o"$item"; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 "$unrar_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$item"; done
		elif [[ "$unrar_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		fi
	fi
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	elif [[ "$(ls $item | egrep -i "\.zip$")" ]]; then
		searchPath=`find -L "$item" -maxdepth 1 ! -name "._*" -type f | egrep -i "\.zip$"`;
		if [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o `echo "$f"` -d "$item"; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o `echo "$f"` -d "$item" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o `echo "$f"` -d "$item"; done
		elif [[ "$unzip_bin" == *unzip* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o `echo "$f"` -d "$item" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$item"; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$item"; done
		elif [[ "$unzip_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		fi
	fi
done

## Delete Mac OS X invisible files and sample from temp folder
for item in $(find "$temp_folder_without_slash"); do
	item=`echo "$item"`
	if [[ "$item" == */.AppleDouble* ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then rm -rf "$item"
	elif [[ "$(echo "$item" | egrep -i "^sample[^A-Za-z0-9_]" )" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.ts$" )" ]] || [[ "$(echo "$item" | egrep -i "[^A-Za-z0-9_]sample[^A-Za-z0-9_]" )" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.ts$" )" ]]; then rm -rf "$item"
	fi
done

## Count number of resulting files and exit if no supported file
count=0 && files=$(( $count + $(find "$temp_folder_without_slash" -type f | egrep -i "$supported_extensions_rev" | wc -l) ))
if [ "$has_display" == "yes" ] && [[ $files -eq 0 ]]; then if [ ! "$folder_short" ]; then folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`; fi && mv "$temp_folder_without_slash" "$destination_folder$folder_short" && rm -f "$log_file" && echo "Sorry, I cannot detect any supported file" && if [[ "$delete_third_party_log" == "yes" && "$third_party_log" != "no" ]]; then rm -f "$third_party_log"; fi && exit
elif [[ $files -eq 0 ]]; then if [ ! "$folder_short" ]; then folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`; fi && mv "$temp_folder_without_slash" "$destination_folder$folder_short" && rm -f "$log_file" && if [[ "$delete_third_party_log" == "yes" && "$third_party_log" != "no" ]]; then rm -f "$third_party_log"; fi && exit
fi

## If only one resulting file rename it according to the initial torrent
if [[ $files -eq 1 ]]; then
	if [ ! "$folder_short" ]; then folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`; fi
	item=`echo "$(find "$temp_folder_without_slash" -type f | egrep -i "$supported_extensions_rev")"`;
	extension=`echo "$item" | sed 's;.*\.;.;'`;
	if [[ "$item" != "$temp_folder$folder_short$extension" ]]; then mv "$item" "$temp_folder$folder_short$extension"; fi && echo "$temp_folder$folder_short$extension" >> "$log_file"
	subtitles_dest=`echo "$subtitles_directory/$(basename "$item")"`
	if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" == "yes" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.divx$")" ]]; then mkdir -p "$subtitles_directory" && echo "$folder_short$extension" > "$subtitles_dest"; fi
	folder_short=""
fi

## If more than one file, create folder named as the initial one and move the resulting files there
if [[ $files -gt 1 ]]; then for directory in $(find "$temp_folder_without_slash" -type d); do
	if [ ! "$folder_short" ]; then folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`; fi
	if [ "$(ls $directory | egrep -i "$music_extensions_rev" )" ]; then
		audioFiles=`ls $directory | egrep -i "$music_extensions_rev"`;
		for f in $(echo -e "$audioFiles"); do
			item=`echo "$directory/$f"`;
			depth=$(( $(echo "$directory/" | sed "s;$torrent_directory;;g" | sed "s;[^/];;g" | wc -c) - 1 ))
			if [[ $depth -eq 1 ]]; then destination_name="$temp_folder$folder_short/"; elif [[ $depth -gt 1 ]]; then destination_name="$temp_folder$folder_short/$(echo "$item" | sed "s;$temp_folder;;g" | sed "s;/; - ;g")"; fi
			mkdir -p "$temp_folder$folder_short/" && mv -f "$item" "$destination_name"
		done
	elif [ "$(ls $directory | egrep -i "$supported_extensions_rev" )" ]; then
		otherFiles=`ls $directory | egrep -i "$supported_extensions_rev"`;
		for f in $(echo -e "$otherFiles"); do item=`echo "$directory/$f"`; mkdir -p "$temp_folder$folder_short/" && mv -f "$item" "$temp_folder$folder_short/"; done
	fi
done
for item in $(find "$temp_folder$folder_short" -type f | egrep -i "$supported_extensions_rev"); do
	subtitles_dest=`echo "$subtitles_directory/$(basename "$item")"`
	already_subtitles=`echo "$(echo "$item" | sed 's/\(.*\)\..*/\1\.srt/')"`
	if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" == "yes" && ! -f "$already_subtitles" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.divx$")" ]]; then mkdir -p "$subtitles_directory" && echo "$(basename "$item")" > "$subtitles_dest"; fi
	echo "$item" >> "$log_file"
done
fi

######################### Optional functionalities ################################


if [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" ]]; then echo "$temp_folder$folder_short" >> "$log_file"; fi

## Try to solve TV Shown Numbering issues
if [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([123456789])([xX])([0-9])([0-9])")" ]] || [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([01])([0-9])([0-3])([0-9])([^pPiI])")" ]] || [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Trying to solve TV Shows numbering issues";  fi
if [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([123456789])([xX])([0-9])([0-9])")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([01])([0-9])([0-3])([0-9])([^pPiI])")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" ]]; then for line in $(cat "$log_file"); do
	item=`echo "$(basename "$line")"`;
	ren_file=`echo "$item"`;
	source=`echo "$line"`;
	if [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([123456789])([xX])([0-9])([0-9])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([123456789])([xX])([0-9])([0-9])")" && -d "$line" ]]; then
		ren_file=`echo "$item" | sed 's;\([123456789]\)\([xX]\)\([0-9]\)\([0-9]\);S0\1E\3\4;g'`;
	elif [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([. _-])([01])([0-9])([0-3])([0-9])([^pPiI])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([. _-])([01])([0-9])([0-3])([0-9])([^pPiI])")" && -d "$line" ]]; then
		ren_file=`echo "$item" | sed 's;\([. _-]\)\([01]\)\([0-9]\)\([0-3]\)\([0-9]\)\([^pPiI]\);\1S\2\3E\4\5\6;g'`;
	elif [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([^eE])([12345689])([012345])([0-9])([^0123456789pPiI])")" && -d "$line" ]]; then
		ren_file=`echo "$item" | sed 's;\([^eE]\)\([12345689]\)\([012345]\)\([0-9]\)\([^0123456789pPiI]\);\1S0\2E\3\4\5;g'`;
	fi
	bis="_bis"
	ren_location=`echo "$(dirname "$source")/$ren_file"`;
	ren_temp_location=`echo "$(dirname "$source")/$ren_file$bis"`;
	source_bis=`echo "$line"`;
	source_ter=$(echo "$line" | sed "s;\([][)(]\);\\\\\1;g") && source_ter=`echo "$source_ter"`;
	ren_location_bis=$(echo "$ren_location" | sed "s;\([][)(]\);\\\\\1;g") && ren_location_bis=`echo "$ren_location_bis"`;
	if [ "$has_display" == "yes" ] && [ "$item" != "$ren_file" ]; then echo "- Renaming $item to $ren_file";  fi
	if [[ -d "$ren_location" && "$(dirname "$source")/" == "$temp_folder" && "$item" != "$ren_file" ]]; then mv -f "$source" "$ren_temp_location"; rm -rf "$ren_location"; source="$ren_temp_location"; fi
	if [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" != "yes" ]; then mv -f "$source" "$ren_location" && sed -i '' "s;^$source_ter;$ren_location_bis;g" "$log_file"
	elif [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" == "yes" ]; then mv -f "$source" "$ren_location" && sed -i "s;^$source_ter;$ren_location_bis;g" "$log_file"
	fi
done
fi


## Cleanup filenames
if [[ "$has_display" == "yes" && "$clean_up_filenames" == "yes" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Cleaning up filenames";  fi
if [[ "$clean_up_filenames" == "yes" ]]; then for line in $(cat "$log_file"); do
	item=`echo "$(basename "$line")"`;
	ren_file=`echo "$item"`;
	source=`echo "$line"`;
	quality=""
	if [ -d "$source" ]; then extension="" && title_clean=`echo "$item"`; else extension=`echo "$item" | sed 's;.*\.;.;'` && title_clean=`echo "$item" | sed 's/\(.*\)\..*/\1/'`; fi
	title_clean_bis=`echo "$title_clean" | sed 's/\([\._]\)\([^ ]\)/ \2/g' | sed "s/^/_/g" | sed "s/$/_/g" | sed "s/A/a/g" | sed "s/B/b/g" | sed "s/C/c/g" | sed "s/D/d/g" | sed "s/E/e/g" | sed "s/F/f/g" | sed "s/G/g/g" | sed "s/H/h/g" | sed "s/I/i/g" | sed "s/J/j/g" | sed "s/K/k/g" | sed "s/L/l/g" | sed "s/M/m/g" | sed "s/N/n/g" | sed "s/O/o/g" | sed "s/P/p/g" | sed "s/Q/q/g" | sed "s/R/r/g" | sed "s/S/s/g" | sed "s/T/t/g" | sed "s/U/u/g" | sed "s/V/v/g" | sed "s/W/w/g" | sed "s/X/x/g" | sed "s/Y/y/g" | sed "s/Z/z/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*a/\1\2\3A/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*b/\1\2\3B/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*c/\1\2\3C/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*d/\1\2\3D/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*e/\1\2\3E/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*f/\1\2\3F/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*g/\1\2\3G/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*h/\1\2\3H/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*i/\1\2\3I/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*j/\1\2\3J/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*k/\1\2\3K/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*l/\1\2\3L/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*m/\1\2\3M/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*n/\1\2\3N/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*o/\1\2\3O/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*p/\1\2\3P/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*q/\1\2\3Q/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*r/\1\2\3R/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*s/\1\2\3S/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*t/\1\2\3T/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*u/\1\2\3U/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*v/\1\2\3V/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*w/\1\2\3W/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*x/\1\2\3X/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*y/\1\2\3Y/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*z/\1\2\3Z/g" | sed "s/^_//g"`;
	title_clean_ter="$title_clean_bis"
	for q in $(echo -e "$(echo "$movies_detect_patterns,$movies_detect_patterns_pt_2" | sed "s;,;\\\n;g")"); do if [ "$(echo "$title_clean_ter" | egrep -i "[. _-]$q[. _-]")" ]; then regexp_pat="$(echo "$q" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")"; quality=" ($q)"; title_clean_ter="$(echo "$title_clean_ter" | sed "s;$(echo "$title_clean_ter" | egrep -o "[. _-]$regexp_pat[. _-]").*;_;")"; fi; done
	for i in $(echo -e "$(echo "$other_movies_patterns" | sed "s;,;\\\n;g")"); do if [ "$(echo "$title_clean_ter" | egrep -i "[. _-]$i[. _-]")" ]; then regexp_pat="$(echo "$i" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")"; title_clean_ter="$(echo "$title_clean_ter" | sed "s;$(echo "$title_clean_ter" | egrep -o "[. _-]$regexp_pat[. _-]").*;_;")"; fi; done
	title_clean_ter=`echo "$title_clean_ter" | sed "s/_*$//g"`
	if [[ "$repack_handling" == "yes" && "$(echo "$item" | egrep -i "([. _])repack([. _])|([. _])proper([. _])|([. _])rerip([. _])")" ]]; then is_repack=" REPACK"; else is_repack=""; fi
	if [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([sS])([0-9])([0-9])([eE])([0-9])([0-9])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] || [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([sS])([0-9])([0-9])([eE])([0-9])([0-9])")" && -d "$source" ]]; then
		if [ "$quality" != " (720p)" ] && [ "$quality" != " (1080p)" ]; then quality=""; fi
		series_title=`echo "$title_clean_ter" | sed 's;.\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;;'`;
		series_episode=`echo "$item" | sed 's;.*\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;S\2\3E\5\6;g'`;
		ren_file=`echo "$series_title $series_episode$is_repack$quality$extension"`;
	elif [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])")" && "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] || [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])")" && -d "$source" ]]; then
		talk_show_title=`echo "$title_clean_ter" | sed 's/\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\)/\1\2\3\4-\5\6-\7\8/g'`;
		ren_file=`echo "$talk_show_title$quality$extension"`;
	elif [[ "$clean_up_filenames" == "yes" && "$(echo "$line" | egrep -i "$movies_extensions_rev")" ]] && [[ $files -eq 1 ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] || [[ "$clean_up_filenames" == "yes" && -d "$source" ]]; then
		ren_file=`echo "$title_clean_ter$quality$extension"`;
	fi
	bis="_bis"
	ren_location=`echo "$(dirname "$source")/$ren_file"`;
	ren_temp_location=`echo "$(dirname "$source")/$ren_file$bis"`;
	source_bis=`echo "$line"`;
	source_ter=$(echo "$line" | sed "s;\([][)(]\);\\\\\1;g") && source_ter=`echo "$source_ter"`;
	ren_location_bis=$(echo "$ren_location" | sed "s;\([][)(]\);\\\\\1;g") && ren_location_bis=`echo "$ren_location_bis"`;
	if [ "$has_display" == "yes" ] && [ "$item" != "$ren_file" ]; then echo "- Renaming $item to $ren_file";  fi
	if [[ -d "$ren_location" && "$(dirname "$source")/" == "$temp_folder" && "$item" != "$ren_file" ]]; then mv -f "$source" "$ren_temp_location"; rm -rf "$ren_location"; source="$ren_temp_location"; fi
	if [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" != "yes" ]; then mv -f "$source" "$ren_location" && sed -i '' "s;^$source_ter;$ren_location_bis;g" "$log_file"
	elif [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" == "yes" ]; then mv -f "$source" "$ren_location" && sed -i "s;^$source_ter;$ren_location_bis;g" "$log_file"
	fi
done
fi

if [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" && "$gnu_sed_available" != "yes" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" && "$gnu_sed_available" != "yes" ]]; then folder_short=`echo "$(cat "$log_file" | sed -n '$p' | sed 's;.*/;;g')"`; sed -i '' '$d' "$log_file"
elif [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" && "$gnu_sed_available" == "yes" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" && "$gnu_sed_available" == "yes" ]]; then folder_short=`echo "$(cat "$log_file" | sed -n '$p' | sed 's;.*/;;g')"`; sed -i '$d' "$log_file"
fi


## Convert DTS track from MKV files to AC3, img disc images to iso disc images and creates a folder and a cuesheet for Wii backups
if [ "$has_display" == "yes" ] && [[ "$dts_post" == "yes" || "$img_post" == "yes" || "$wii_post" == "yes" ]] && [ "$(cat "$log_file" | egrep -i "\.mkv$|\.img$|\.wii")" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Converting DTS track to AC3, IMG to ISO and Creating Wii Cuesheet";  fi
for line in $(cat "$log_file"); do
	source_trimmed=`echo "$line" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
	source_file=`echo "$line"`
	source_filename=`echo "$(basename "$line")"`
	source_dir=`echo "$(dirname "$line")"`
	if [ "$(echo "$line" | egrep -i "\.mkv$" )" ] && [ "$dts_post" == "yes" ]; then
		if [ "$has_display" == "yes" ]; then echo "- Converting $source_filename from DTS to AC3";  fi
		if [ "$has_display" == "yes" ]; then "$mkvdts2ac3_bin" -w "$temp_folder" -k "$source_file"; else "$mkvdts2ac3_bin" -w "$temp_folder" -k "$source_file"; fi
	elif [ "$(echo "$line" | egrep -i "\.img$" )" ] && [ "$img_post" == "yes" ]; then
		iso=`echo "$source_dir/$source_trimmed.iso"`
		if [ "$has_display" == "yes" ]; then echo "- Converting $source_filename to an ISO";  fi
		if [ "$has_display" == "yes" ]; then "$ccd2iso_bin" "$source_file" "$iso"; else "$ccd2iso_bin" "$source_file" "$iso" > /dev/null 2>&1; fi
		iso_size="$(stat -c %s "$iso")"
		if [ "$iso_size" -lt 1000 ]; then
			if [ "$has_display" == "yes" ]; then echo "Actually $source_filename is probably already an ISO";  fi
			rm -f "$iso" && mv -f "$source_file" "$iso"
		else rm "$source_file"
		if [ "$gnu_sed_available" != "yes" ]; then sed -i '' "s;$source_file;$iso;g" "$log_file"; else sed -i "s;$source_file;$iso;g" "$log_file"; fi
		fi
	elif [ "$(echo "$line" | egrep -i "\.wii" )" ] && [ "$(echo "$line" | egrep -i "\.iso$" )" ] && [ "$wii_post" == "yes" ]; then
		source_trimmed=`echo "$line" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
		new_folder=`echo "$temp_folder$source_trimmed/"`
		dvd_file=`echo "$new_folder$source_trimmed.dvd"`
		if [ ! "$folder_short" ] && [ "$gnu_sed_available" != "yes" ]; then
			mkdir -p "$new_folder" && mv -f "$source_file" "$new_folder" && sed -i '' "s;$source_file;$new_folder$source_filename;g" "$log_file"
		elif [ ! "$folder_short" ] && [ "$gnu_sed_available" == "yes" ]; then
			mkdir -p "$new_folder" && mv -f "$source_file" "$new_folder" && sed -i "s;$source_file;$new_folder$source_filename;g" "$log_file"
		fi
		if [ "$has_display" == "yes" ]; then echo "- Creating a Cuesheet for $source_filename";  fi
		echo "$source_filename" > "$dvd_file"
		echo "$dvd_file" >> "$log_file"
	fi
done

## Copy or move TV Shows, movies and music to a specific folder
if [ "$has_display" == "yes" ] && [[ "$tv_shows_post" != "no" || "$music_post" != "no" || "$movies_post" != "no" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Taking care of TV Shows, Music and Movie files";  fi
additional_permissions="additional_permissions"
for line in $(cat "$log_file"); do
	source_file=`echo "$line"`
	source_filename=`echo "$(basename "$line")"`
	# Getting default values for post
	if [ "$(echo "$line" | egrep -i "$music_extensions_rev" )" ] && [ "$music_post" != "no" ]; then new_destination=`echo "$music_post_path"`
	elif [[ "$(echo "$line" | egrep -i "$movies_detect_patterns_rev" )" ||Ê"$(echo "$line" | egrep -i "$movies_detect_patterns_pt_2_rev" )" ]] && [ "$(echo "$line" | egrep -i "$movies_extensions_rev" )" ] && [ "$movies_post" != "no" ]; then new_destination=`echo "$movies_post_path"`
	fi
	# Determining Series and Season for tv_shows_post_path_mode
	if [ "$(echo "$source_filename" | egrep -i "([. _])s([0-9])([0-9])e([0])([0-9])([. _])")" ]; then series_season_v1=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \4;g'` && series_season_v2=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \3\4;g'` && series_title=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;\1;' | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;\1;'`; elif [ "$(echo "$source_filename" | egrep -i "([. _])s([0-9])([0-9])e([1-9])([0-9])([. _])")" ]; then series_season_v1=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \3\4;g'` && series_season_v2=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \3\4;g'` && series_title=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;\1;' | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;\1;'`; elif [ "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]; then series_season_v1=`echo "$source_filename" | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;Season \2\3\4\5;g'` && series_season_v2=`echo "$source_filename" | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;Season \2\3\4\5;g'` && series_title=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;\1;' | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;\1;'`; fi
	# Reverting to default if tv_shows_post_path_mode is disabled
	if [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "no" ]]; then new_destination=`echo "$tv_shows_post_path"`; fi
	# Adding surrounding folder to the path
	if [ "$folder_short" ]; then new_destination=`echo "$new_destination$folder_short/"`; fi
	if [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "s" ]]; then new_destination=`echo "$tv_shows_post_path$series_title/"`; elif [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "ss" ]]; then new_destination=`echo "$tv_shows_post_path$series_title/$series_season_v1/"`; elif [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "sss" ]]; then new_destination=`echo "$tv_shows_post_path$series_title/$series_season_v2/"`; fi
	# Starting copying and moving
	if [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [[ "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" && "$tv_shows_post" == "copy" ]]; then mkdir -p "$new_destination" && if [ "$has_display" == "yes" ]; then echo "- Copying $source_filename to $new_destination";  fi && cp "$source_file" "$new_destination" && echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions"
	elif [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [[ "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" && "$tv_shows_post" == "move" && "$gnu_sed_available" != "yes" ]]; then mkdir -p "$new_destination" && if [ "$has_display" == "yes" ]; then echo "- Moving $source_filename to $new_destination";  fi && mv "$source_file" "$new_destination" && echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions" && sed -i '' "s;$source_file;$new_destination$source_filename;g" "$log_file"
	elif [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [[ "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" && "$tv_shows_post" == "move" && "$gnu_sed_available" == "yes" ]]; then mkdir -p "$new_destination" && if [ "$has_display" == "yes" ]; then echo "- Moving $source_filename to $new_destination";  fi && mv "$source_file" "$new_destination" && echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions" && sed -i "s;$source_file;$new_destination$source_filename;g" "$log_file"
	elif [[ "$(echo "$line" | egrep -i "$music_extensions_rev")" && "$music_post" == "copy" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$movies_post" == "copy" ]]; then mkdir -p "$new_destination" && if [ "$has_display" == "yes" ]; then echo "- Copying $source_filename to $new_destination";  fi && cp "$source_file" "$new_destination" && echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions"
	elif [[ "$(echo "$line" | egrep -i "$music_extensions_rev")" && "$music_post" == "move" && "$gnu_sed_available" != "yes" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$movies_post" == "move" && "$gnu_sed_available" != "yes" ]]; then mkdir -p "$new_destination" && if [ "$has_display" == "yes" ]; then echo "- Moving $source_filename to $new_destination";  fi && mv "$source_file" "$new_destination" && echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions" && sed -i '' "s;$source_file;$new_destination$source_filename;g" "$log_file"
	elif [[ "$(echo "$line" | egrep -i "$music_extensions_rev")" && "$music_post" == "move" && "$gnu_sed_available" == "yes" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$movies_post" == "move" && "$gnu_sed_available" == "yes" ]]; then mkdir -p "$new_destination" && if [ "$has_display" == "yes" ]; then echo "- Moving $source_filename to $new_destination";  fi && mv "$source_file" "$new_destination" && echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions" && sed -i "s;$source_file;$new_destination$source_filename;g" "$log_file"
	fi
done
if [[ "$folder_short" && -d "$temp_folder$folder_short" ]]; then
	files_in_folder_short=$(ls -1 "$temp_folder$folder_short" | wc -l)
	if [[ "$music_post" == "move" && $files_in_folder_short -eq 0 ]] || [[ "$tv_shows_post" == "move" && $files_in_folder_short -eq 0 ]] || [[ "$movies_post" == "move" && $files_in_folder_short -eq 0 ]]; then folder_short="" && folder_short_deleted="yes"; fi
fi

## Edit files and folders permissions
if [ ! -f "$temp_folder$additional_permissions" ]; then echo "" > "$temp_folder$additional_permissions"; fi
if [[ "$has_display" == "yes" && "$user_perm_post" != "no" ]] || [[ "$has_display" == "yes" && "$files_perm_post" != "no" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Setting permissions";  fi

for line in $(cat "$log_file"); do
	if [[ "$user_perm_post" != "no" && "$group_perm_post" != "no" ]] || [[ "$files_perm_post" != "no" && "$folder_perm_post" != "no" ]]; then
		item=`echo "$line"`
		if [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && "$has_display" == "yes" ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chown "$user_perm_post":"$group_perm_post" "$item"; fi
		if [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chmod "$files_perm_post" "$item"; fi
		if [[ -f "$item" && "$edit_perm_as_sudo" == "no" && "$files_perm_post" != "no" ]]; then chmod "$files_perm_post" "$item"; fi
		if [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chmod "$folder_perm_post" "$item"; fi
		if [[ -d "$item" && "$edit_perm_as_sudo" == "no" && "$folder_perm_post" != "no" ]]; then chmod "$folder_perm_post" "$item"; fi
	fi
done
for line in $(cat "$temp_folder$additional_permissions"); do
	if [[ "$user_perm_post" != "no" && "$group_perm_post" != "no" ]] || [[ "$files_perm_post" != "no" && "$folder_perm_post" != "no" ]]; then
		item=`echo "$line"`
		if [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && "$has_display" == "yes" ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chown "$user_perm_post":"$group_perm_post" "$item"; fi
		if [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -f "$item" && "$edit_perm_as_sudo" == "yes" && "$files_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chmod "$files_perm_post" "$item"; fi
		if [[ -f "$item" && "$edit_perm_as_sudo" == "no" && "$files_perm_post" != "no" ]]; then chmod "$files_perm_post" "$item"; fi
		if [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && $(id -u) -eq 0 ]] || [[ -d "$item" && "$edit_perm_as_sudo" == "yes" && "$folder_perm_post" != "no" && "$has_display" == "yes" ]]; then sudo chmod "$folder_perm_post" "$item"; fi
		if [[ -d "$item" && "$edit_perm_as_sudo" == "no" && "$folder_perm_post" != "no" ]]; then chmod "$folder_perm_post" "$item"; fi
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
for line in $(cat "$temp_folder$additional_permissions"); do
	if [ "$reset_timestamp" == "yes" ]; then
		item=`echo "$line"`
		touch "$line"
	fi
done

## Move content of temp folder to destination folder
item=`echo "$(find "$temp_folder_without_slash" -type f | egrep -i "$supported_extensions_rev")"`
if [ "$folder_short" ]; then mv "$temp_folder$folder_short" "$destination_folder"
elif [ ! "$folder_short" ]; then
	for line in $(cat "$log_file"); do
		item=`echo "$line"`
		if [[ "$(echo "$line" | egrep -i "$supported_extensions_rev")" && "$(echo "$line" | egrep -i "$temp_folder")" ]]; then mv "$item" "$destination_folder"; fi
	done
fi
if [[ "$gnu_sed_available" != "yes" ]]; then rm -rf "$temp_folder_without_slash" && sed -i '' "s;^$temp_folder;$destination_folder;g" "$log_file"; else rm -rf "$temp_folder_without_slash" && sed -i "s;^$temp_folder;$destination_folder;g" "$log_file"; fi


## Use a source / destination log shared with a third party app - Add path to enable
count=0 && files=$(( $count + $(cat "$log_file"|wc -l) ))
if [[ $files -eq 1 ]] && [ "$third_party_log" != "no" ]; then echo "$(cat "$log_file")" > "$third_party_log"; fi
if [[ $files -gt 1 ]] && [ "$third_party_log" != "no" ]; then folder_name=`echo "$destination_folder$folder_short"`; echo "$folder_name" > "$third_party_log"; fi
if [ "$third_party_log" != "no" ] && [ "$user_perm_post" == "yes" ]; then chown "$user_perm_post":"$group_perm_post" "$third_party_log" && sudo chmod "$files_perm_post" "$third_party_log"; fi

## Delete third party log if required
if [ "$delete_third_party_log" == "yes" ] && [ "$third_party_log" != "no" ]; then rm -f "$third_party_log"; fi

##################################################################################

## Restore running environment
export TR_TORRENT_DIR=""
export TR_TORRENT_NAME=""
export torrent=""
rm -f "$log_file"

## This is the subtitles routine. If srt files are found in the subtitles directory, they will be renamed and moved to the destination folder
if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" != "no" && -d "$subtitles_directory" && "$(find "$subtitles_directory" -maxdepth 1 ! -name "._*" -name "*.srt" -type f)" ]]; then
 	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Fetching new subtitles from the subtitles folder";  fi
 	export subtitles_mode="yes"
 	has_display="no"
 	for line in $(find "$subtitles_directory" -maxdepth 1 ! -name "._*" -name "*.srt" -type f); do
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

