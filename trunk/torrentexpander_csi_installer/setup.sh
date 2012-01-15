#!/bin/sh

prepare()
{
	# Try to correct paths list
	path_backup="$PATH"; 
	initial_path=":$PATH:"; 
	new_path="$PATH"; 
	for test_path in $(echo -e "/usr/local/sbin\n/usr/local/bin\n/usr/sbin\n/usr/bin\n/sbin\n/bin\n/usr/games\n/usr/bin\n/bin\n/usr/sbin\n/sbin\n/usr/local/bin\n/usr/X11/bin\n/Applications\n/opt/syb/sigma/bdj/jvm/bin\n/usr/bin/X11\n/opt/syb/app/bin\n/opt/syb/app/sbin\n/opt/syb/sigma/bin\n/nmt/apps"); do 
		if [[ -d "$test_path" && "$initial_path" != *:$test_path:* ]]; then 
			echo -e "Information: adding $test_path to your paths list";
			new_path="$new_path:$test_path"; 
		fi
	done 
	PATH="$new_path";
	export PATH="$new_path";
	echo -e "Information: this is your current paths list:\n$PATH";
	
	# Check for Transmission
	if [ -d /share/Apps/Transmission ]; then
		echo 'Information: transmission is installed';
	else
		echo 'Error: transmission is not installed, you must install it from CSI before';
	fi
	# Check for opkg
	if [ -f "/usr/local/bin/opkg" ]; then
		echo 'Information: opkg is installed';
		# Check for an internet connection
		if [ "$(wget -qO- -T 5 http://repository.nmtinstaller.com/appinit_version)" != "" ]; then
			internet="yes"
			echo 'Information: internet connection avaiable';
		else
			internet="no"
			echo 'Warning: no internet connection';
		fi
		# Try to update opkg
			if [ "$internet" == "yes" ]; then
				echo 'Information: updating opkg';
				opkg update;
				wait
			else
				echo 'Warning: i can not update opkg without internet connection';
			fi
		# Check for unzip and try to install it
		if [ ! -f "/usr/local/bin/unzip" ]; then
			echo 'Information: unzip (CSI version) is not installed';
			if [ "$internet" == "yes" ]; then
				echo 'Installing unzip';
				opkg install unzip;
				wait;
			else
				echo 'Error: i can not install unzip without internet connection';
			fi
		else
			echo 'Information: unzip (CSI version) is already installed';
		fi
		# Check for unrar and try to install it
		if [ ! -f "/usr/local/bin/unrar" ]; then
			echo 'Information: unrar is not installed';
			if [ "$internet" == "yes" ]; then
				echo 'Installing unrar'
				opkg install unrar;
				wait;
			else
				echo 'Error: i can not install unrar without internet connection';
			fi
		else
			echo 'Information: unrar is already installed';
		fi
		# Check for wget and try to install it
		if [ ! -f "/usr/local/bin/wget" ]; then
			echo 'Information: wget (CSI version) is not installed';
			if [ "$internet" == "yes" ]; then
				echo 'Installing wget'
				opkg install wget;
				wait;
			else
				echo 'Error: i can not install wget without internet connection';
			fi
		else
			echo 'Information: wget (CSI version) is already installed';
		fi
		# Check for busybox and try to install it
		if [ ! -f "/usr/local/bin/busybox" ]; then
			echo 'Information: busybox is not installed';
			if [ "$internet" == "yes" ]; then
				echo 'Installing busybox'
				opkg install busybox;
				wait;
			else
				echo 'Error: i can not install busybox without internet connection';
			fi
		else
			echo 'Information: busybox is already installed';
		fi
		# Install Torrentexpander
		if [[ "$(opkg status unzip)" != "" || -f "/usr/bin/unzip" ]] && [ "$(opkg status unrar)" != "" ] && [[ "$(opkg status wget)" != "" || -f "/bin/wget" ]] && [ "$(opkg status busybox)" != "" ] && [ -d /share/Apps/Transmission ]; then
			echo 'Information: torrentexpander setup started';
			install;
		else
			echo 'Error: torrentexpander setup aborted';			
			export PATH="$path_backup";
		fi
	else
		echo 'Error: opkg not avaiable, you must install local package from CSI before';
		export PATH="$path_backup";
	fi
}

install()
{
	/share/Apps/AppInit/appinit.cgi stop transmission
	/share/Apps/AppInit/appinit.cgi webserver_disable
	wait
	
	count=0
	while [ "$(pgrep transmission-daemon)" ] && [[ $count -lt 60 ]]; do
		echo 'Waiting for transmission stop'
		sleep 1;
		count=$(( count + 1 )); 
	done
	
	count=0
	while [ "$(pgrep -f php5server)" ] && [[ $count -lt 60 ]]; do
		echo 'Waiting for php5server stop'
		sleep 1;
		count=$(( count + 1 )); 
	done
	
	chmod -R 777 /share/Apps/TorrentExpander/
	chown -R nmt:nmt /share/Apps/TorrentExpander/bin/torrentexpander_settings.ini
	
	if [ ! -e /share/Download/Expanded ]; then
		mkdir -p /share/Download/Expanded
		chmod -R 777 /share/Download/Expanded
		chown -R nmt:nmt /share/Download/Expanded
    fi

	if [ ! -e /share/Video/Movies ]; then
        mkdir -p /share/Video/Movies
		chmod -R 777 /share/Video/Movies
		chown -R nmt:nmt /share/Video/Movies
    fi

	if [ ! -e /share/Video/Series ]; then
        mkdir -p /share/Video/Series
		chmod -R 777 /share/Video/Series
		chown -R nmt:nmt /share/Video/Series
    fi
	
	if [ -f "/share/Apps/Transmission/config/settings.json" ]; then
		echo 'Editing transmission config file'
		sed -i 's/^\( *\)\"script-torrent-done-enabled\"\: .*$/\1\"script-torrent-done-enabled\"\: true\,/g' /share/Apps/Transmission/config/settings.json
		sed -i 's/^\( *\)\"script-torrent-done-filename\"\: .*$/\1\"script-torrent-done-filename\"\: \"\/share\/Apps\/TorrentExpander\/bin\/torrentexpander.sh\"\,/g' /share/Apps/Transmission/config/settings.json
		chmod 666 /share/Apps/Transmission/config/settings.json
		chown nmt:nmt /share/Apps/Transmission/config/settings.json
	fi
	
	/share/Apps/AppInit/appinit.cgi start transmission
	/share/Apps/AppInit/appinit.cgi webserver_enable
	wait
}

uninstall()
{
	/share/Apps/AppInit/appinit.cgi stop transmission
	/share/Apps/AppInit/appinit.cgi webserver_disable
	wait;
	
	count=0
	while [ $(pgrep transmission-daemon) ] && [[ $count -lt 60 ]]; do
		# echo 'Waiting for transmission stop'
		sleep 1;
		count=$(( count + 1 )); 
	done
	
	count=0
	while [ $(pgrep -f php5server) ] && [[ $count -lt 60 ]]; do
		# echo 'Waiting for php5server stop'
		sleep 1;
		count=$(( count + 1 )); 
	done
	
	if [ -f /share/Apps/Transmission/config/settings.json ]; then
		# echo 'Editing transmission config file'
		sed -i 's/^\( *\)\"script-torrent-done-enabled\"\: .*$/\1\"script-torrent-done-enabled\"\: false\,/g' /share/Apps/Transmission/config/settings.json
		sed -i 's/^\( *\)\"script-torrent-done-filename\"\: .*$/\1\"script-torrent-done-filename\"\: \"\",/g' /share/Apps/Transmission/config/settings.json
		chmod 666 /share/Apps/Transmission/config/settings.json
		chown nmt.root /share/Apps/Transmission/config/settings.json
	fi
	
	/share/Apps/AppInit/appinit.cgi start transmission
	/share/Apps/AppInit/appinit.cgi webserver_enable
	wait;
}


case "$1" in
    install)
    prepare
    ;;
    
    uninstall)
    uninstall
    ;;
esac
