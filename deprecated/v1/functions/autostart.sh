autolaunch(){
    systemctl daemon-reload
    systemctl enable --now $1.service
    systemctl start $1
}

dislaunch(){
    systemctl stop $1
    systemctl disable --now $1
}

# For Alpine specifically (enabling SSH)
autolaunch_openrc(){
    rc-update add $1 default
    rc-service $1 start
}

dislaunch_openrc(){
    rc-service $1 stop
    rc-update del $1 default
}