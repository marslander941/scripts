#!/bin/bash

# This is bash script that makes sure killswitch and portforwading are enabled,
# then uses fzf to prompt the user to select a server to connect to.
# The final section outputs the Server location, VPN IP, Port, and protocol.

clear

# Make sure killswitch is auto
piaks=$(piactl -u dump daemon-settings | jq -r '.killswitch')
while [ "$piaks" != "auto" ]; do
	echo "\e[31Killswitch is disabled!\e[0m"
	echo Resetting settings
	piactl resetsettings && echo Reset successful. ; sleep 1
	# Update the value
	piaks=$(piactl -u dump daemon-settings | jq -r '.killswitch')
done

# Killswitch is now set to "auto" (Or this line won't even run at all)
echo -e "\e[32mKillswitch is set to auto.\e[0m"

# Enable background process to make sure killswitch stays enabled
if piactl background enable; then
    echo -e "\e[32mPIA background enable successful\e[0m"  # Green text
else
    echo -e "\e[31mError: PIA background enable failed\e[0m"  # Red text
    exit 1
fi

# Enable port forwarding
piactl set requestportforward true && echo -e "\e[32mPortforwarding is enabled\e[0m" || echo -e "\e[31mPortforwarding failed\e[0m \nrun 'piactl set requestportforward true'" 

# Check if the VPN is connected
connection_state=$(piactl get connectionstate)
if [ "$connection_state" == "Connected" ]; then
    # Disable the VPN
    echo "VPN is connected. Disabling..."
	piactl disconnect
	while [ "$(piactl get connectionstate)" != "Disconnected" ]; do
		sleep 2
	done
    echo "VPN disconnected successfully."
fi

if [ "$#" -eq 1 ]; then
    # Connect to the specified server
    echo "Connecting to VPN server: $1"
	piactl set region "$1" && piactl connect
else
	while true; do

		# Use fzf to interactively select the server name
		regions=$(piactl get regions)
		chosenservername=$(echo "$regions" | fzf --height 20)

	    piactl set region "$chosenservername" && piactl connect
	
	    if [ $? -eq 0 ]; then
			
		echo

		# Make sure the status is correct before proceeding
		while [ "$(piactl get connectionstate)" != "Connected" ]; do sleep 1; done
		echo -e "\e[32mConnection State:\e[0m $(piactl get connectionstate)"

		while [ "$(piactl get vpnip)" == "Unknown" ]; do sleep 1; done
		echo -e "\e[32mVPN IP:\e[0m $(piactl get vpnip)"
				
		echo -e "\e[32mSelected Region:\e[0m $(piactl get region)"
		echo -e "\e[32mPort Forward:\e[0m $(piactl get portforward)"
		echo -e "\e[32mVPN Protocol:\e[0m $(piactl get protocol)"
        break

	    else
			clear
			sleep 5
	        echo -e "\e[31mNo connection. Try again.\e[0m"
	    fi
	done
fi

# Prompt user for confirmation
echo "This script will reset and configure UFW for Private Internet Access."
read -p "Do you want to continue? (y/n): " response

if [[ "$response" =~ ^[Yy]$ ]]; then
    # Resetting UFW firewall settings
    echo "Resetting UFW firewall..."
    sudo ufw reset

    # Re-enabling UFW
    echo "Re-enabling UFW..."
    sudo ufw enable

    # Adding Private Internet Access (PIA) port to UFW
    pia_port=$(piactl get portforward)
    echo "Adding PIA port to UFW: $pia_port"
    sudo ufw allow $pia_port

    # Displaying UFW status in verbose mode
    echo -e "\nCurrent UFW status:"
    sudo ufw status verbose

    echo "UFW configuration completed successfully."
else
    echo "UFW configuration canceled."
fi

