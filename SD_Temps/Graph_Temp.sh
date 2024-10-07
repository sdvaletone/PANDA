#!/bin/bash

# Define colors for console output
GREEN='\033[0;32m'
NC='\033[0m' # No color

# Prompt the user for duration and validate input (multiples of 5 between 5 and 240)
while true; do
  read -p "Enter the logging duration in minutes (multiples of 5, between 5 and 240): " DURATION_MINUTES
  if [[ "$DURATION_MINUTES" =~ ^[0-9]+$ ]] && [ "$DURATION_MINUTES" -ge 5 ] && [ "$DURATION_MINUTES" -le 240 ] && ((DURATION_MINUTES % 5 == 0)); then
    break
  else
    echo "Please enter a valid number that is a multiple of 5 and between 5 and 240."
  fi
done

# Calculate the total number of iterations and interval
INTERVAL_SECONDS=10
ITERATIONS=$((DURATION_MINUTES * 60 / INTERVAL_SECONDS))
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="temperature_log_${TIMESTAMP}.csv"

# Check if sensors command is available
if ! command -v sensors &> /dev/null; then
  echo "sensors command not found. Please install lm-sensors."
  exit 1
fi

# Log header to CSV
if ! echo "Timestamp,NVMe Temp,GPU Temp,Battery Temp,System Temp,SoC,Charge Current" > "$OUTPUT_FILE"; then
  echo "Error writing to $OUTPUT_FILE. Please check your permissions."
  exit 1
fi

# Start message
echo "Starting temperature logging for $DURATION_MINUTES minutes. Data will be saved in $OUTPUT_FILE."

# Initialize arrays for storing values for averages and statistics
nvme_values=()
gpu_values=()
battery_values=()
system_values=()
soc_values=()        # State of Charge
charge_current_values=()  # Charge Current

# Log temperature with a countdown message every minute
for ((i=1; i<=ITERATIONS; i++)); do
  # Capture time and each relevant temperature sensor
  TIME="$(date +"%H:%M:%S")"  # Changed timestamp format to HH:MM:SS
  NVME_TEMP=$(sensors | awk '/Composite/ {print $2}' | tr -d '+°C')
  GPU_TEMP=$(sensors | awk '/edge:/ {print $2}' | tr -d '+°C')
  BATTERY_TEMP=$(sensors | awk '/Battery Temp/ {print $3}' | tr -d '+°C')
  SYSTEM_TEMP=$(sensors | awk '/^temp1:/ {print $2}' | tr -d '+°C')
  SOC=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo "N/A")
  CHARGE_CURRENT=$(echo $(( $(cat /sys/class/power_supply/BAT1/current_now) / 1000 )) 2>/dev/null || echo "N/A")

  # Log data to CSV, with "N/A" if a sensor is unavailable
  echo "$TIME,${NVME_TEMP:-N/A},${GPU_TEMP:-N/A},${BATTERY_TEMP:-N/A},${SYSTEM_TEMP:-N/A},${SOC:-N/A},${CHARGE_CURRENT:-N/A}" >> "$OUTPUT_FILE"

  # Append temperatures to arrays
  nvme_values+=(${NVME_TEMP:-0})
  gpu_values+=(${GPU_TEMP:-0})
  battery_values+=(${BATTERY_TEMP:-0})
  system_values+=(${SYSTEM_TEMP:-0})
  soc_values+=(${SOC:-0})
  charge_current_values+=(${CHARGE_CURRENT:-0})

  # Average every 5 minutes (or 30 iterations)
  if (( i % 30 == 0 )); then
    nvme_avg=$(printf "%s\n" "${nvme_values[@]}" | awk '{sum+=$1} END {print sum/NR}')
    gpu_avg=$(printf "%s\n" "${gpu_values[@]}" | awk '{sum+=$1} END {print sum/NR}')
    battery_avg=$(printf "%s\n" "${battery_values[@]}" | awk '{sum+=$1} END {print sum/NR}')
    system_avg=$(printf "%s\n" "${system_values[@]}" | awk '{sum+=$1} END {print sum/NR}')
    soc_avg=$(printf "%s\n" "${soc_values[@]}" | awk '{sum+=$1} END {print sum/NR}')
    charge_current_avg=$(printf "%s\n" "${charge_current_values[@]}" | awk '{sum+=$1} END {print sum/NR}')

    echo "Average over last 5 minutes,${nvme_avg},${gpu_avg},${battery_avg},${system_avg},${soc_avg},${charge_current_avg}" >> "$OUTPUT_FILE"

    # Clear arrays for the next 5-minute interval
    nvme_values=()
    gpu_values=()
    battery_values=()
    system_values=()
    soc_values=()
    charge_current_values=()
  fi

  # Countdown message every 6 iterations (1 minute)
  if (( i % 6 == 0 )); then
    MINUTES_LEFT=$((DURATION_MINUTES - i * INTERVAL_SECONDS / 60))
    echo -e "${GREEN}$MINUTES_LEFT minute(s) remaining...${NC}"
  fi

  # Progress indication
  PERCENTAGE=$((i * 100 / ITERATIONS))
  printf "\rProgress: ["
  for ((j=0; j<PERCENTAGE/5; j++)); do printf "="; done
  for ((j=PERCENTAGE/5; j<20; j++)); do printf " "; done
  printf "] %d%%" "$PERCENTAGE"

  # Wait for the specified interval
  sleep "$INTERVAL_SECONDS"
done

# Final message
echo -e "\n\nTemperature logging complete. Data saved in $OUTPUT_FILE."
