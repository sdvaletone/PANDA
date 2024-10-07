#!/bin/bash

# Define colors for console output
GREEN='\033[0;32m'
NC='\033[0m' # No color

# Set logging interval in seconds and define 5-minute mark for reporting
INTERVAL_SECONDS=10
FIVE_MINUTE_INTERVAL=30  # 5 minutes / 10 seconds = 30 iterations
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="temperature_log_${TIMESTAMP}.csv"
HIGH_TEMP_FILE="high_temp_events_${TIMESTAMP}.csv"

# Function to prompt the user for input
get_user_input() {
  while true; do
    read -p "Enter the target SoC percentage to stop logging (1-100) or 't' to set a time limit: " TARGET_SOC
    if [[ "$TARGET_SOC" =~ ^[0-9]+$ ]] && [ "$TARGET_SOC" -ge 1 ] && [ "$TARGET_SOC" -le 100 ]; then
      break
    elif [[ "$TARGET_SOC" == "t" ]]; then
      read -p "Enter the time limit in minutes (1-240): " TIME_LIMIT
      if [[ "$TIME_LIMIT" =~ ^[0-9]+$ ]] && [ "$TIME_LIMIT" -ge 1 ] && [ "$TIME_LIMIT" -le 240 ]; then
        TARGET_SOC="time"
        END_TIME=$(( $(date +%s) + (TIME_LIMIT * 60) ))
        break
      else
        echo "Please enter a valid number between 1 and 240."
      fi
    else
      echo "Please enter a valid number between 1 and 100 or 't' to set a time limit."
    fi
  done
}

# Check if sensors command is available
if ! command -v sensors &> /dev/null; then
  echo "sensors command not found. Please install lm-sensors."
  exit 1
fi

# Initial prompt for user input
get_user_input

# Log header to CSV
if ! echo "Timestamp,NVMe Temp,GPU Temp,Battery Temp,System Temp,SoC,Charge Current" > "$OUTPUT_FILE"; then
  echo "Error writing to $OUTPUT_FILE. Please check your permissions."
  exit 1
fi

# Log header for high temperature events CSV
if ! echo "Timestamp,High Temp Events" > "$HIGH_TEMP_FILE"; then
  echo "Error writing to $HIGH_TEMP_FILE. Please check your permissions."
  exit 1
fi

# Initialize high temp counters
nvme_high_count=0
gpu_high_count=0
battery_high_count=0
system_high_count=0

while true; do
  # Start message
  echo "Starting temperature logging until SoC reaches $TARGET_SOC% or time limit is reached. Data will be saved in $OUTPUT_FILE and high temperature events in $HIGH_TEMP_FILE."

  # Main logging loop
  iteration=0
  while :; do
    # Capture date and each relevant temperature sensor
    DATE="$(date +"%H:%M:%S")"
    NVME_TEMP=$(sensors | awk '/Composite/ {print $2}' | tr -d '+°C')
    GPU_TEMP=$(sensors | awk '/edge:/ {print $2}' | tr -d '+°C')
    BATTERY_TEMP=$(sensors | awk '/Battery Temp/ {print $3}' | tr -d '+°C')
    SYSTEM_TEMP=$(sensors | awk '/^temp1:/ {print $2}' | tr -d '+°C')

    # Get SoC and charge current
    SOC=$(cat /sys/class/power_supply/BAT1/capacity)
    CHARGE_CURRENT=$(( $(cat /sys/class/power_supply/BAT1/current_now) / 1000 ))

    # Check if the temperature readings are numeric
    if ! [[ "$NVME_TEMP" =~ ^-?[0-9]+$ ]]; then NVME_TEMP=0; fi
    if ! [[ "$GPU_TEMP" =~ ^-?[0-9]+$ ]]; then GPU_TEMP=0; fi
    if ! [[ "$BATTERY_TEMP" =~ ^-?[0-9]+$ ]]; then BATTERY_TEMP=0; fi
    if ! [[ "$SYSTEM_TEMP" =~ ^-?[0-9]+$ ]]; then SYSTEM_TEMP=0; fi
    if ! [[ "$SOC" =~ ^-?[0-9]+$ ]]; then SOC=0; fi
    if ! [[ "$CHARGE_CURRENT" =~ ^-?[0-9]+$ ]]; then CHARGE_CURRENT=0; fi

    # Log high temperature events if any sensor is above 35°C
    HIGH_TEMP_EVENT=""
    if [ "$NVME_TEMP" -gt 35 ]; then
      HIGH_TEMP_EVENT+=" NVMe"
      nvme_high_count=$((nvme_high_count + 1))
    fi
    if [ "$GPU_TEMP" -gt 35 ]; then
      HIGH_TEMP_EVENT+=" GPU"
      gpu_high_count=$((gpu_high_count + 1))
    fi
    if [ "$BATTERY_TEMP" -gt 35 ]; then
      HIGH_TEMP_EVENT+=" Battery"
      battery_high_count=$((battery_high_count + 1))
    fi
    if [ "$SYSTEM_TEMP" -gt 35 ]; then
      HIGH_TEMP_EVENT+=" System"
      system_high_count=$((system_high_count + 1))
    fi

    # Log data to CSV
    echo "$DATE,$NVME_TEMP,$GPU_TEMP,$BATTERY_TEMP,$SYSTEM_TEMP,$SOC,$CHARGE_CURRENT" >> "$OUTPUT_FILE"

    # Log high temperature events to separate CSV file
    if [[ -n $HIGH_TEMP_EVENT ]]; then
      echo "$DATE,$HIGH_TEMP_EVENT" >> "$HIGH_TEMP_FILE"
    fi

    # Display progress
    echo -e "${GREEN}SoC: $SOC%, Target: $TARGET_SOC%, Charging Current: ${CHARGE_CURRENT}mA${NC}"

    # Every 5 minutes, log the high temperature counts and reset them
    if (( iteration % FIVE_MINUTE_INTERVAL == 0 && iteration != 0 )); then
      echo "$DATE,,,5-Min High Temp Count - NVMe: $nvme_high_count, GPU: $gpu_high_count, Battery: $battery_high_count, System: $system_high_count" >> "$OUTPUT_FILE"
      nvme_high_count=0
      gpu_high_count=0
      battery_high_count=0
      system_high_count=0
    fi

    # Exit when SoC reaches the target percentage or time limit is reached
    if [[ "$TARGET_SOC" != "time" && "$SOC" -ge "$TARGET_SOC" ]]; then
      echo -e "\nTarget SoC reached. Logging complete."
      break
    elif [[ "$TARGET_SOC" == "time" && "$(date +%s)" -ge "$END_TIME" ]]; then
      echo -e "\nTime limit reached. Logging complete."
      break
    fi

    # Wait for the specified interval and increment iteration
    sleep "$INTERVAL_SECONDS"
    ((iteration++))
  done

  # Prompt the user to continue or exit
  read -p "Logging complete. Enter 'y' to log again, 'n' to exit: " REPEAT
  if [[ "$REPEAT" == "n" ]]; then
    echo "Exiting the script."
    break
  else
    # Get new user input for the next round of logging
    get_user_input
  fi
done

echo "Temperature logging complete. Data saved in $OUTPUT_FILE and high temperature events in $HIGH_TEMP_FILE."
