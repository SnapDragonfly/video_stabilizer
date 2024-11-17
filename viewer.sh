#!/bin/bash

# Configuration:
VIRTUAL_SCREEN_WIDTH=1920
VIRTUAL_SCREEN_HEIGHT=1080
VIRTUAL_SCREEN_FPS=60

# PID files for tracking processes
MSPOSD_PIDFILE="/var/run/msposd.pid"
WFB_PIDFILE="/var/run/wfb.pid"
VIDEO_PIDFILE="/var/run/video.pid"

# commands for wrapper
# wfb_rx -p 17 -i 7669206 -u 14560 -K /etc/gs.key wlan1
CMD_WFBRX="wfb_rx -p 17 -i 7669206 -u 14560 -K /etc/gs.key wlan1"
# ./msposd --master 127.0.0.1:14560 --osd -r 50 --ahi 1 --matrix 11
CMD_MSPOSD="./msposd --master 127.0.0.1:14560 --osd -r 50 --ahi 1 --matrix 11"
# video-viewer --input-codec=h265 rtp://@:5600
CMD_VIDEO="video-viewer --input-codec=h265 rtp://@:5600"

# Define the module's lock file directory (ensure the directory exists)
LOCK_DIR="/tmp/module_locks"
MODULE_NAME=$(basename "$0" .sh)

look() {
    # Look at the status of each relevant process and display their PIDs
    echo "Looking at the status of processes..."
    
    echo ""
    echo ${CMD_MSPOSD}
    # Check if msposd is running and print PID
    if ps aux | grep "${CMD_MSPOSD}" | grep -v grep; then
        export DISPLAY=:0
        MSPOSD_PID=$(ps aux | grep "${CMD_MSPOSD}" | grep -v grep | awk '{print $2}')
        echo "msposd is running with PID: $MSPOSD_PID"
    else
        echo "msposd is not running."
    fi

    echo ""
    echo ${CMD_VIDEO}
    # Check if video-viewer is running and print PID
    if ps aux | grep "${CMD_VIDEO}" | grep -v grep; then
        export DISPLAY=:0
        VIDEO_PIDFILE=$(ps aux | grep "${CMD_VIDEO} | grep -v grep" | awk '{print $2}')
        echo "video-viewer is running with PID: $VIDEO_PIDFILE"
    else
        echo "video-viewer is not running."
    fi

    echo ""
    echo ${CMD_WFBRX}
    # Check if wfb_rx is running and print PID
    if ps aux | grep "${CMD_WFBRX}" | grep -v grep; then
        WFB_PID=$(ps aux | grep "${CMD_WFBRX} | grep -v grep" | awk '{print $2}')
        echo "wfb_rx is running with PID: $WFB_PID"
        echo ""
        systemctl status wifibroadcast@gs
    else
        echo "wfb_rx is not running."
        echo ""
        systemctl status wifibroadcast@gs
    fi
}

# Start the module
start() {
    # Create lock file to indicate the module is running
    touch "${LOCK_DIR}/${MODULE_NAME}.lock"
    echo "Starting module ${MODULE_NAME}..."
    
    # Add the logic to start the module here, e.g., running a specific command or script
    # Example: ./start_module_command.sh

    # Step 1: Start wfb (wifibroadcast)
    echo "Starting wifibroadcast..."
    systemctl start wifibroadcast@gs
    sleep 1 # initialization
    ${CMD_WFBRX} &
    echo $! > $WFB_PIDFILE
    sleep 3 # initialization

    # Step 2: Start video-viewer script
    echo "Starting video-viewer..."
    export DISPLAY=:0
    OUTPUT_FILE="file://$(date +"%Y-%m-%d_%H-%M-%S").mp4"
    CMD_VIDEO="${CMD_VIDEO} ${OUTPUT_FILE}"
    echo ${CMD_VIDEO}
    ${CMD_VIDEO} &
    echo $! > $VIDEO_PIDFILE
    sleep 3 # initialization

    # Step 3: Start msposd (OSD drawing)
    echo "Starting msposd..."
    export DISPLAY=:0
    #export DISPLAY=:${VIRTUAL_SCREEN}
    ${CMD_MSPOSD} &
    echo $! > $MSPOSD_PIDFILE
    sleep 3 # initialization

    echo "${MODULE_NAME} started."
}

# Stop the module
stop() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        echo "Stopping module ${MODULE_NAME}..."
        rm "${LOCK_DIR}/${MODULE_NAME}.lock"
        # Add the logic to stop the module here, e.g., killing a process or stopping a service
        # Example: kill $(pidof module_process)

        # Stop all processes if they are running and remove PID files
        echo "Stopping all processes..."

        if [ -f "$MSPOSD_PIDFILE" ]; then
            kill $(cat $MSPOSD_PIDFILE)
            sleep 1
            rm -f $MSPOSD_PIDFILE
            echo "msposd stopped."
        fi

        if [ -f "$VIDEO_PIDFILE" ]; then
            kill -s SIGINT $(cat $VIDEO_PIDFILE)
            sleep 1
            rm -f $VIDEO_PIDFILE
            echo "video-viewer stopped."
        fi

        if [ -f "$WFB_PIDFILE" ]; then
            # Stop wfb_rx manually if it's running
            kill $(cat $WFB_PIDFILE)
            sleep 1
            rm -f $WFB_PIDFILE
            systemctl stop wifibroadcast@gs
            echo "wifibroadcast stopped."
        fi

        echo "${MODULE_NAME} stopped."
    else
        echo "Module ${MODULE_NAME} is not running. Cannot stop."
    fi
}

# Show the status of the module
status() {
    if [ -e "${LOCK_DIR}/${MODULE_NAME}.lock" ]; then
        echo "Module ${MODULE_NAME} is running."

        # Check if each process is running based on PID files and display their PIDs
        echo "Checking status of all processes..."

        echo ""
        if [ -f "$MSPOSD_PIDFILE" ] && ps -p $(cat $MSPOSD_PIDFILE) > /dev/null; then
            echo "msposd is running with PID: $(cat $MSPOSD_PIDFILE)"
        else
            echo "msposd is not running."
        fi

        echo ""
        if [ -f "$VIDEO_PIDFILE" ] && ps -p $(cat $VIDEO_PIDFILE) > /dev/null; then
            echo "video-viewer is running with PID: $(cat $VIDEO_PIDFILE)"
        else
            echo "video-viewer is not running."
        fi

        echo ""
        if [ -f "$WFB_PIDFILE" ] && ps -p $(cat $WFB_PIDFILE) > /dev/null; then
            echo "wifibroadcast (wfb_rx) is running with PID: $(cat $WFB_PIDFILE)"
            echo ""
            systemctl status wifibroadcast@gs
        else
            echo "wifibroadcast (wfb_rx) is not running."
            echo ""
            systemctl status wifibroadcast@gs
        fi
    else
        echo "Module ${MODULE_NAME} is not running."
        look
    fi
}

# Restart the module
restart() {
    stop
    start
}

# Dispatcher to handle commands
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
    restart)
        restart
        ;;
    *)
        echo "Usage: $0 {start|stop|status|restart}"
        exit 1
        ;;
esac
