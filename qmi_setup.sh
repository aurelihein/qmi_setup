#! /bin/sh
# Author: Aurelien BOUIN <aurelien.bouin@captina.dev>
# Date : 21/05/2019

VERSION="1.0.0"
DRY_RUN=0
SCRIPTNAME="modem_cmd.sh"

###
# This script automate the setup of QMI supported wwan devices.
#
# Tested on following environment:
#   * Lenovo ThinkPad X220 (4286-CTO)
#   * Gentoo/Linux, Linux Kernel 3.9.6
#   * NTT Docomo UIM card (Xi LTE SIM)
#   * Sierra Wireless, Inc. Gobi 3000 wireless wan module
#     (FRU 60Y3257, vendor and device id is 1199:9013)
#     memo:
#       I recommend to check if your wwan module works fine
#       for your mobile broadband provider with Windows
#       especially if you imported the device from other country.
#       You may have to initialize your device for your region.
#   * Required kernel config (other modules may be also required):
#     - qmi_wwan (CONFIG_USB_NET_QMI_WWAN)
#     - qcserial (CONFIG_USB_SERIAL_QUALCOMM)
#   * Required settings:
#     - you may have to create /etc/qmi-network.conf.
#       My qmi-network.conf has only a line "APN=mopera.net".
#

# your wwan device name created by qmi_wwan kernel module
# check it with "ip a" or "ifconfig -a". it may be wwan0?
WWAN_DEV=wwan0
# your cdc_wdm modem location
CDC_WDM=/dev/cdc-wdm0
# this script uses following qmi commands
QMICLI=/usr/bin/qmicli
QMI_NETWORK=/usr/bin/qmi-network
# the places of following commands vary depending on your distribution
IFCONFIG=/sbin/ifconfig
DHCPCD=/sbin/dhcpcd
SUDO=/usr/bin/sudo
QMI_PROFILE_FILE=/etc/qmi-network.conf

helpmsg() {
    echo "usage: $SUDO $0 {start|stop|restart|status|setup [APN]|version|strength}"
    exit 1
}

qmi_start() {
    echo "Starting qmi handle"
    [ $DRY_RUN -eq 1 ] && exit 0
    $COMMAND_PREFIX $IFCONFIG $WWAN_DEV up
    $COMMAND_PREFIX $QMICLI -d $CDC_WDM --dms-set-operating-mode=online
    if [ $? -ne 0 ]; then
    echo "your wwan device may be RFKilled?"
    exit 1
    fi
    $COMMAND_PREFIX $QMI_NETWORK $CDC_WDM start
    $COMMAND_PREFIX $DHCPCD $WWAN_DEV
}

qmi_stop() {
    echo "Stopping qmi handle"
    [ $DRY_RUN -eq 1 ] && exit 0
    $COMMAND_PREFIX $QMI_NETWORK $CDC_WDM stop
    if [ -e /var/run/dhcpcd-${WWAN_DEV}.pid ]
    then
        $COMMAND_PREFIX kill $(cat /var/run/dhcpcd-${WWAN_DEV}.pid)
    fi
    $COMMAND_PREFIX $IFCONFIG $WWAN_DEV down
}

qmi_strength() {
    dbm=$($COMMAND_PREFIX $QMICLI -d $CDC_WDM --nas-get-signal-strength | tr "'" " " | grep Network | head -1 | awk '{print $4}')
    echo -n "Signal strength is "
    if [ $dbm -ge -73 ]; then
    echo -n 'Excellent'
    elif [ $dbm -ge -83 ]; then
    echo -n 'Good'
    elif [ $dbm -ge -93 ]; then
    echo -n 'OK'
    elif [ $dbm -ge -109 ]; then
    echo -n 'Marginal'
    else
    echo Unknown
    fi
    echo " (${dbm} dBm)"
}

qmi_status() {
    [ $DRY_RUN -eq 1 ] && exit 0
    $COMMAND_PREFIX $QMI_NETWORK $CDC_WDM status
    qmi_strength
}

qmi_setup() {
    if [ -z "$2" ]
    then
        echo "You need to specify the APN name when using setup"
        helpmsg
        exit 1
    fi
    echo "Setting-up connection with APN $2"
    [ $DRY_RUN -eq 1 ] && exit 0
    echo "APN=$2" | sudo tee ${QMI_PROFILE_FILE}
}

# check permission
if [ $(whoami) != 'root' -a 'ri'"$1"'en' != "riversionen" ]
then
    echo "warning: root permission required. setting command prefix to 'sudo'."
    COMMAND_PREFIX=$SUDO
fi

# run commands
case $1 in
    start)
        qmi_start
        ;;
    stop)
        qmi_stop
        ;;
    restart)
        qmi_stop
        qmi_start
        ;;
    status)
        qmi_status
        ;;
    strength)
        qmi_strength
        ;;
    setup)
        qmi_setup
        ;;
    version)
        echo "v:$VERSION"
        exit 0
        ;;
    *)
        helpmsg
        ;;
esac
