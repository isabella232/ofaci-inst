# tempest.sh - DevStack extras script

if is_service_enabled tempest; then
    if [[ "$1" == "source" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "install" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
        # no-op
        :
    elif [[ "$1" == "stack" && "$2" == "extra" ]]; then
        echo_summary "Add Tempest configuration"
        iniset $TEMPEST_CONFIG compute ping_timeout 300
        iniset $TEMPEST_CONFIG compute ssh_timeout 196
        sleep 30
        sudo ovs-vsctl set Controller br-int inactivity_probe=30000
    elif [[ "$1" == "stack" && "$2" == "post-extra" ]]; then
        # no-op
        :
    fi

    if [[ "$1" == "unstack" ]]; then
        # no-op
        :
    fi

    if [[ "$1" == "clean" ]]; then
        # no-op
        :
    fi
fi

