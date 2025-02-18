dot_countdown() {
    if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Please provide a valid number as the argument."
        return 1
    fi

    local number=$1
    local count=$((number / 5))
    local dots=""

    # Create the line of dots
    for ((i = 0; i < count; i++)); do
        dots+="."
    done

    echo -n "$dots"

    # Sequentially remove each dot every 5 seconds
    while [ ${#dots} -gt 0 ]; do
        sleep 5
        dots=${dots%.}
        echo -ne "\r$dots "
    done
    echo
}

# Example usage:
dot_countdown 25

