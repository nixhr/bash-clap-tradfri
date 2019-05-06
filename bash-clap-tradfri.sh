#!/bin/bash
# Author    Nikola Pavkovic <nikola@iprojekt.hr>
# License   GPL-3.0  
# This script will detect claps and double claps and will change the lighting according to detected claps
# Based on bash-clap project by daweedm: https://github.com/daweedm

# Configuration
source ./ikea.conf
kernel=$(uname -s)

detection_percentage_start="10%"
detection_percentage_end="10%"
clap_amplitude_threshold="0.3"
clap_energy_threshold="0.3"
clap_max_duration="1500"
max_history_length="10"
light_watch_tv="0"
src="auto" # See README.md
lastClapTime="0"

if [ "$src" = "auto" ]; then
	if [ "$kernel" = "Darwin" ]; then
		src="coreaudio default" # macOS
	else
		src="alsa hw:0,0" # Linux
	fi
fi

clap () {
    coap-client -m put -u "$user" -k "$securitykey" -e '{ "3311": [{ "5850": 1 }] }' "coaps://${hubip}:5684/15001/65540"
    coap-client -m put -u "$user" -k "$securitykey" -e '{ "3311": [{ "5850": 0 }] }' "coaps://${hubip}:5684/15001/65537"
    coap-client -m put -u "$user" -k "$securitykey" -e '{ "3311": [{ "5850": 0 }] }' "coaps://${hubip}:5684/15001/65538"
    lastClapTime=$(($(date +%s%N)/1000000))
}

double_clap () {
    coap-client -m put -u "$user" -k "$securitykey" -e '{ "3311": [{ "5850": 0 }] }' "coaps://${hubip}:5684/15001/65540"
    coap-client -m put -u "$user" -k "$securitykey" -e '{ "3311": [{ "5850": 1 }] }' "coaps://${hubip}:5684/15001/65537"
    coap-client -m put -u "$user" -k "$securitykey" -e '{ "3311": [{ "5850": 1 }] }' "coaps://${hubip}:5684/15001/65538"
    lastClapTime=$(($(date +%s%N)/1000000))
}

while true; do
	sound_data=$(sox -t $src input.wav silence 1 0.0001 $detection_percentage_start 1 0.1 $detection_percentage_end −−no−show−progress stat 2>&1)
	length=$(echo "$sound_data" | sed -n 's#^Length[ ]*(seconds):[^0-9]*\([0-9.]*\)$#\1#p')
	max_amplitude=$(echo "$sound_data" | sed -n 's#^Maximum[ ]*amplitude:[^0-9]*\([0-9.]*\)$#\1#p')
	rms_amplitude=$(echo "$sound_data" | sed -n 's#^RMS[ ]*amplitude:[^0-9]*\([0-9.]*\)$#\1#p')

	lenght_test=$(echo "$length < $clap_max_duration" | bc -l)
	amplitude_test=$(echo "$max_amplitude > $clap_amplitude_threshold" | bc -l)
	energy_test=$(echo "$rms_amplitude < $clap_energy_threshold" | bc -l)

	if [ "$lenght_test" = "1" ] && [ "$amplitude_test" = "1" ] && [ "$energy_test" = "1" ]; then
    now=$(($(date +%s%N)/1000000))
    timediff=$(expr $now - $lastClapTime)
    echo "now: $now lastClapTime: $lastClapTime timediff: $timediff"
    if [ "$timediff" -ge "1000" ]
    then 
		  clap
    else 
      double_clap
    fi
	fi
done
