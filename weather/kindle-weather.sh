#!/bin/sh
set -x

PWD=$(pwd)
#LOG="/mnt/us/clock.log"
LOG="/dev/null"
FBINK="fbink -q"
FONT="regular=/usr/java/lib/fonts/Futura-Medium.ttf"
CITY="Rangiora"

# Hardware specific settings
FBROTATE="echo -n 0 > /sys/devices/platform/imx_epdc_fb/graphics/fb0/rotate"
BACKLIGHT="/sys/devices/platform/imx-i2c.0/i2c-0/0-003c/max77696-bl.0/backlight/max77696-bl/brightness"
BATTERY="/sys/devices/system/wario_battery/wario_battery0/battery_capacity"
TEMP_SENSOR="/sys/devices/system/wario_battery/wario_battery0/battery_temperature"

wait_for_wifi() {
  return `lipc-get-prop com.lab126.wifid cmState | grep -e "CONNECTED" | wc -l`
}

clear_screen(){
    $FBINK -f -c
    $FBINK -f -c
}

### Prep Kindle...
echo "`date '+%Y-%m-%d_%H:%M:%S'`: ------------- Startup ------------" >> $LOG

### No way of running this if wifi is down.
if [ `lipc-get-prop com.lab126.wifid cmState` != "CONNECTED" ]; then
	exit 1
fi

$FBINK -w -c -f -m -t $FONT,size=20,top=410,bottom=0,left=0,right=0 "Starting Weather..." > /dev/null 2>&1


### stop processes that we don't need
stop lab126_gui
# stop otaupd
#stop phd
#stop tmd
stop x
#stop todo
# stop mcsd
# stop archive
# stop dynconfig
#stop dpmd
#stop appmgrd
#stop stackdumpd

#/etc/init/framework stop

sleep 2

### turn off 270 degree rotation of framebuffer device
eval $FBROTATE

### Set lowest cpu clock
echo powersave > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
### Disable Screensaver
lipc-set-prop com.lab126.powerd preventScreenSaver 1

clear_screen

# Add weather code to icon mapping function
get_weather_icon(){
    local code=$1
    case $code in
        113) echo "wi-day-sunny" ;; # Clear/Sunny
        116) echo "wi-cloud" ;; # Partly Cloudy
        119) echo "wi-cloudy" ;; # Cloudy
        122) echo "wi-fog" ;; # Overcast
        143) echo "wi-sprinkle" ;; # Mist
        176) echo "wi-sprinkle" ;; # Patchy rain nearby
        179) echo "wi-snow" ;; # Patchy snow nearby
        182) echo "wi-sleet" ;; # Patchy sleet nearby
        185) echo "wi-sleet" ;; # Patchy freezing drizzle nearby
        200) echo "wi-storm-showers" ;; # Thundery outbreaks nearby
        227) echo "wi-snow" ;; # Blowing snow
        230) echo "wi-snow-wind" ;; # Blizzard
        248) echo "wi-fog" ;; # Fog
        260) echo "wi-fog" ;; # Freezing fog
        263) echo "wi-sprinkle" ;; # Patchy light drizzle
        266) echo "wi-sprinkle" ;; # Light drizzle
        281) echo "wi-sleet" ;; # Freezing drizzle
        284) echo "wi-sleet" ;; # Heavy freezing drizzle
        293) echo "wi-sprinkle" ;; # Patchy light rain
        296) echo "wi-sprinkle" ;; # Light rain
        299) echo "wi-showers" ;; # Moderate rain at times
        302) echo "wi-showers" ;; # Moderate rain
        305) echo "wi-rain" ;; # Heavy rain at times
        308) echo "wi-rain" ;; # Heavy rain
        311) echo "wi-sleet" ;; # Light freezing rain
        314) echo "wi-sleet" ;; # Moderate or heavy freezing rain
        317) echo "wi-sleet" ;; # Light sleet
        320) echo "wi-sleet" ;; # Moderate or heavy sleet
        323) echo "wi-snow" ;; # Patchy light snow
        326) echo "wi-snow" ;; # Light snow
        329) echo "wi-snow" ;; # Patchy moderate snow
        332) echo "wi-snow" ;; # Moderate snow
        335) echo "wi-snow" ;; # Patchy heavy snow
        338) echo "wi-snow" ;; # Heavy snow
        350) echo "wi-hail" ;; # Ice pellets
        353) echo "wi-sprinkle" ;; # Light rain shower
        356) echo "wi-rain" ;; # Moderate or heavy rain shower
        359) echo "wi-rain" ;; # Torrential rain shower
        362) echo "wi-sleet" ;; # Light sleet showers
        365) echo "wi-sleet" ;; # Moderate or heavy sleet showers
        368) echo "wi-snow" ;; # Light snow showers
        371) echo "wi-snow" ;; # Moderate or heavy snow showers
        374) echo "wi-sleet" ;; # Light showers of ice pellets
        377) echo "wi-hail" ;; # Moderate or heavy showers of ice pellets
        386) echo "wi-storm-showers" ;; # Patchy light rain with thunder
        389) echo "wi-thunderstorm" ;; # Moderate or heavy rain with thunder
        392) echo "wi-storm-showers" ;; # Patchy light snow with thunder
        395) echo "wi-storm-showers" ;; # Moderate or heavy snow with thunder
        *) echo "wi-na" ;; # Default/NA
    esac
}

update_weather(){

    FONT="regular=/usr/java/lib/fonts/Futura-Medium.ttf"

    BATTERY="/sys/devices/system/wario_battery/wario_battery0/battery_capacity"
    BAT=$(cat $BATTERY)
    TIME=$(date '+%H:%M')
    TEMP_SENSOR="/sys/devices/system/wario_battery/wario_battery0/battery_temperature"
    INSIDE_TEMP_C=$(cat $TEMP_SENSOR)
    let INSIDE_TEMP_C="($INSIDE_TEMP_C-32)*5/9"

    # Add font definition at the top
    WEATHER_FONT="regular=/var/tmp/root/weathericons-regular-webfont.ttf"

    # +3 hours
    N3_FIRST_INDEX=0
    N3_INDEX=$(( (($(date +'%H%M') + 300 ) / 300 ) ))
    if [[ $N3_INDEX -gt 7 ]]; then
        N3_INDEX=$(( $N3_INDEX - 8 ))
        N3_FIRST_INDEX=1
    fi
    # +6 hours
    N6_FIRST_INDEX=0
    N6_INDEX=$(( (($(date +'%H%M') + 600 ) / 300 ) ))
    if [[ $N6_INDEX -gt 7 ]]; then
        N6_INDEX=$(( $N6_INDEX - 8 ))
        N6_FIRST_INDEX=1
    fi
    # 9am next day
    N24_INDEX=3

    WEATHER_DATA=$(curl -s https://wttr.in/$CITY?format=j1)

    WEATHER_PARSED=$(echo "$WEATHER_DATA" | jq -r "[ \
    .current_condition[0].temp_C, \
    .weather[$N3_FIRST_INDEX].hourly[$N3_INDEX].tempC, \
    .weather[$N3_FIRST_INDEX].hourly[$N3_INDEX].windspeedKmph, \
    .weather[$N3_FIRST_INDEX].hourly[$N3_INDEX].chanceofrain, \
    .weather[$N3_FIRST_INDEX].hourly[$N3_INDEX].precipMM, \
    .weather[$N3_FIRST_INDEX].hourly[$N3_INDEX].winddirDegree, \
    .weather[$N3_FIRST_INDEX].hourly[$N3_INDEX].weatherCode, \
    .weather[$N6_FIRST_INDEX].hourly[$N6_INDEX].tempC, \
    .weather[$N6_FIRST_INDEX].hourly[$N6_INDEX].windspeedKmph, \
    .weather[$N6_FIRST_INDEX].hourly[$N6_INDEX].chanceofrain, \
    .weather[$N6_FIRST_INDEX].hourly[$N6_INDEX].precipMM, \
    .weather[$N6_FIRST_INDEX].hourly[$N6_INDEX].winddirDegree, \
    .weather[$N6_FIRST_INDEX].hourly[$N6_INDEX].weatherCode, \
    .weather[1].hourly[$N24_INDEX].tempC, \
    .weather[1].hourly[$N24_INDEX].windspeedKmph, \
    .weather[1].hourly[$N24_INDEX].chanceofrain, \
    .weather[1].hourly[$N24_INDEX].precipMM, \
    .weather[1].hourly[$N24_INDEX].winddirDegree, \
    .weather[1].hourly[$N24_INDEX].weatherCode \
    ] | join(\" \")")

    echo "$WEATHER_PARSED" | while read -r OUTSIDE_TEMP_C N3_OUTSIDE_TEMP_C N3_WIND_SPEED_KPH N3_RAIN_PERCENTAGE N3_RAIN_MM N3_WIND_DEGREE N3_WEATHER_CODE N6_OUTSIDE_TEMP_C N6_WIND_SPEED_KPH N6_RAIN_PERCENTAGE N6_RAIN_MM N6_WIND_DEGREE N6_WEATHER_CODE N24_OUTSIDE_TEMP_C N24_WIND_SPEED_KPH N24_RAIN_PERCENTAGE N24_RAIN_MM N24_WIND_DEGREE N24_WEATHER_CODE; do 
        
        N3_WIND_DEGREE=$(( (($N3_WIND_DEGREE + 45 /2 ) / 45) * 45 ))
        N6_WIND_DEGREE=$(( (($N6_WIND_DEGREE + 45 /2 ) / 45) * 45 ))
        N24_WIND_DEGREE=$(( (($N24_WIND_DEGREE + 45 /2 ) / 45) * 45 ))

        N3_ICON=$(get_weather_icon "$N3_WEATHER_CODE")
        N6_ICON=$(get_weather_icon "$N6_WEATHER_CODE")
        N24_ICON=$(get_weather_icon "$N24_WEATHER_CODE")

        if [[ "$N3_RAIN_MM" = "0.0" ]]; then
            N3_RAIN_MM=0
        fi
        if [[ "$N6_RAIN_MM" = "0.0" ]]; then
            N6_RAIN_MM=0
        fi
        if [[ "$N24_RAIN_MM" = "0.0" ]]; then
            N24_RAIN_MM=0
        fi

        FBINK_OPTS="-b -q"

        fbink $FBINK_OPTS -f -c

        fbink $FBINK_OPTS -t $FONT,size=24,top=240,bottom=0,left=20,right=0 "______________________________________"

        fbink $FBINK_OPTS -t $FONT,size=96,top=10,bottom=0,left=50,right=0 "$TIME"
        fbink $FBINK_OPTS --image file=img/home.png -x 45 -y 4
        fbink $FBINK_OPTS -t $FONT,size=48,top=10,bottom=0,left=800,right=0 "$INSIDE_TEMP_C"
        fbink $FBINK_OPTS -m -t $FONT,size=16,top=30,bottom=0,left=900,right=0 "°C"
        fbink $FBINK_OPTS --image file=img/outside.png -x 45 -y 12
        fbink $FBINK_OPTS -t $FONT,size=48,top=150,bottom=0,left=800,right=0 "$OUTSIDE_TEMP_C" -r
        fbink $FBINK_OPTS -m -t $FONT,size=16,top=170,bottom=0,left=900,right=0 "°C"

        # Weather icons
        fbink $FBINK_OPTS -m --image file=img/$N3_ICON.png,w=180,h=0,x=41,y=300
        fbink $FBINK_OPTS -m --image file=img/$N6_ICON.png,w=180,h=0,x=422,y=300
        fbink $FBINK_OPTS -m --image file=img/$N24_ICON.png,w=180,h=0,x=803,y=300

        # Temperature
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=500,bottom=0,left=0,right=900 "$N3_OUTSIDE_TEMP_C"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=510,bottom=0,left=0,right=780 "°C"
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=500,bottom=0,left=0,right=140 "$N6_OUTSIDE_TEMP_C"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=510,bottom=0,left=0,right=20 "°C"
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=500,bottom=0,left=550,right=0 "$N24_OUTSIDE_TEMP_C"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=510,bottom=0,left=640,right=0 "°C"

        # Wind
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=500,bottom=0,left=0,right=600 "$N3_WIND_SPEED_KPH"
        fbink $FBINK_OPTS  --image file=img/$N3_WIND_DEGREE.png,h=40 -x 16 -y 32
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=500,bottom=0,left=120,right=0 "$N6_WIND_SPEED_KPH"
        fbink $FBINK_OPTS  --image file=img/$N6_WIND_DEGREE.png,h=40 -x 39 -y 32
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=500,bottom=0,left=800,right=0 "$N24_WIND_SPEED_KPH"
        fbink $FBINK_OPTS  --image file=img/$N24_WIND_DEGREE.png,h=40 -x 60 -y 32

        # Rain percentage
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=600,bottom=0,left=0,right=900 "$N3_RAIN_PERCENTAGE"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=610,bottom=0,left=0,right=780 "%"
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=600,bottom=0,left=0,right=140 "$N6_RAIN_PERCENTAGE"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=610,bottom=0,left=0,right=20 "%"
        fbink $FBINK_OPTS -m -p -t $FONT,size=36,top=600,bottom=0,left=550,right=0 "$N24_RAIN_PERCENTAGE" 
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=610,bottom=0,left=640,right=0 "%"

        # Rain mm
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=600,bottom=0,left=0,right=600 "$N3_RAIN_MM"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=610,bottom=0,left=0,right=440 "mm"
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=600,bottom=0,left=120,right=0 "$N6_RAIN_MM"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=610,bottom=0,left=290,right=0 "mm"
        fbink $FBINK_OPTS -m -t $FONT,size=36,top=600,bottom=0,left=800,right=0 "$N24_RAIN_MM"
        fbink $FBINK_OPTS -m -t $FONT,size=12,top=610,bottom=0,left=960,right=0 "mm"

        fbink $FBINK_OPTS -t $FONT,size=8,top=0,bottom=0,left=10,right=0 "$BAT%"

        fbink -w -s
    done
}

run (){
    update_weather
    while true; do

        # Sleep to make the system clock drift
        hwclock -s -u

        echo "`date '+%Y-%m-%d_%H:%M:%S'`: Top of loop (awake!)." >> $LOG
        ### Backlight off
        echo -n 0 > $BACKLIGHT

        ### Get weather data and set time via ntpdate every hour
        MINUTE=`date "+%M"`
        if [ "$MINUTE" = "00" ]; then
            echo "`date '+%Y-%m-%d_%H:%M:%S'`: Enabling Wifi" >> $LOG
            ### Enable WIFI, disable wifi first in order to have a defined state
            lipc-set-prop com.lab126.cmd wirelessEnable 1
            TRYCNT=0
            NOWIFI=0
            ### Wait for wifi to come up
            while wait_for_wifi; do
                if [ ${TRYCNT} -gt 30 ]; then
                    ### waited long enough
                    echo "`date '+%Y-%m-%d_%H:%M:%S'`: No Wifi... ($TRYCNT)" >> $LOG
                    NOWIFI=1
                    break
                fi
                WIFISTATE=$(lipc-get-prop com.lab126.wifid cmState)
                echo "`date '+%Y-%m-%d_%H:%M:%S'`: Waiting for Wifi... (try $TRYCNT: $WIFISTATE)" >> $LOG
                ### Are we stuck in READY state?
                if [ "$WIFISTATE" = "READY" ]; then
                    ### we have to reconnect
                    echo "`date '+%Y-%m-%d_%H:%M:%S'`: Reconnecting to Wifi..." >> $LOG
                    /usr/bin/wpa_cli -i wlan0 reconnect

                    ### Could also be that kindle forgot the wpa ssid/psk combo
                    #if [ wpa_cli status | grep INACTIVE | wc -l ]; then...
                fi
                sleep 1
                let TRYCNT=$TRYCNT+1
            done
            echo "`date '+%Y-%m-%d_%H:%M:%S'`: wifi: `lipc-get-prop com.lab126.wifid cmState`" >> $LOG
            echo "`date '+%Y-%m-%d_%H:%M:%S'`: wifi: `wpa_cli status`" >> $LOG

            if [ `lipc-get-prop com.lab126.wifid cmState` = "CONNECTED" ]; then
                ## Finally, set time
                #echo "`date '+%Y-%m-%d_%H:%M:%S'`: Setting time..." >> $LOG
                #ntpdate -s de.pool.ntp.org
                #RC=$?
                #echo "`date '+%Y-%m-%d_%H:%M:%S'`: Time set. ($RC)" >> $LOG
                update_weather
            fi

            #clear_screen
        fi

        ### Disable WIFI
        lipc-set-prop com.lab126.cmd wirelessEnable 0

        BAT=$(cat $BATTERY)
        TIME=$(date '+%H:%M')
        DATE=$(date '+%A, %-d. %B %Y')
        INSIDE_TEMP_C=$(cat $TEMP_SENSOR)
        # convert to centigrade
        let INSIDE_TEMP_C="($INSIDE_TEMP_C-32)*5/9"

        fbink $FBINK_OPTS --cls top=0,left=0,width=700,height=300
        fbink $FBINK_OPTS -t $FONT,size=96,top=10,bottom=0,left=50,right=0 "$TIME"
        fbink $FBINK_OPTS --cls top=0,left=800,width=120,height=140
        fbink $FBINK_OPTS -t $FONT,size=48,top=10,bottom=0,left=800,right=0 "$INSIDE_TEMP_C"
        fbink $FBINK_OPTS -t $FONT,size=8,top=0,bottom=0,left=10,right=0 "$BAT%"
        fbink -w -s

        ### Set Wakeuptimer
        NOW=$(date +%s)
        let WAKEUP_TIME="((($NOW + 59)/60)*60)" # Hack to get next minute
        let SLEEP_SECS=$WAKEUP_TIME-$NOW

        ### Prevent SLEEP_SECS from being negative or just too small
        ### if we took too long
        if [ $SLEEP_SECS -lt 5 ]; then
            let SLEEP_SECS=$SLEEP_SECS+60
        fi
        rtcwake -d /dev/rtc1 -m no -s $SLEEP_SECS
        echo "`date '+%Y-%m-%d_%H:%M:%S'`: Going to sleep for $SLEEP_SECS" >> $LOG
        
        #sleep $SLEEP_SECS
        ### Go into Suspend to Memory (STR)
        echo "mem" > /sys/power/state
    done
}

# Various attempts at exiting via the power button
quit(){
    clear_screen
    $FBINK -w -c -f -m -t $FONT,size=20,top=410,bottom=0,left=0,right=0 "Bye bye..." > /dev/null 2>&1
    start x
    start lab126_gui
    lipc-set-prop com.lab126.powerd preventScreenSaver 0
    echo ondemand >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
}

trap quit EXIT

run &
RUN_PID=$!

# Exit by pressing physical button
while true; do
    key=$(waitforkey)
    if [ "$key" = "116 1" ]; then
        quit
        kill $RUN_PID
        kill -- -$$
    fi
done
