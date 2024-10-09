#!/bin/bash

# Set logging interval and output files
INTERVAL_SECONDS=10
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="temperature_log_${TIMESTAMP}.csv"
HIGH_TEMP_FILE="high_temp_events_${TIMESTAMP}.csv"

# Get target SoC or time limit from user
echo "Enter the target SoC percentage (1-100) or type 't' for time limit:"
read TARGET_SOC
if [[ "$TARGET_SOC" == "t" ]]; then
  echo "Enter time limit in minutes (1-240):"
  read TIME_LIMIT
  END_TIME=$(( $(date +%s) + (TIME_LIMIT * 60) ))
fi

# Log headers
echo "Timestamp,NVMe Temp,GPU Temp,Battery Temp,System Temp,SoC,Charge Current" > "$OUTPUT_FILE"
echo "Timestamp,High Temp Events" > "$HIGH_TEMP_FILE"

# Logging loop
while true; do
  # Get timestamp and sensor data
  DATE=$(date +"%H:%M:%S")
  SENSOR_OUTPUT=$(sensors)
  
  # Parse required fields
  NVME_TEMP=$(echo "$SENSOR_OUTPUT" | awk '/Composite/ {print $2}' | tr -d '+°C')
  GPU_TEMP=$(echo "$SENSOR_OUTPUT" | awk '/edge:/ {print $2}' | tr -d '+°C')
  BATTERY_TEMP=$(echo "$SENSOR_OUTPUT" | awk '/Battery Temp/ {print $3}' | tr -d '+°C')
  SYSTEM_TEMP=$(echo "$SENSOR_OUTPUT" | awk '/^temp1:/ {print $2}' | tr -d '+°C')
  
  # Default values if parsing fails
  NVME_TEMP=${NVME_TEMP:-0}
  GPU_TEMP=${GPU_TEMP:-0}
  BATTERY_TEMP=${BATTERY_TEMP:-0}
  SYSTEM_TEMP=${SYSTEM_TEMP:-0}
  
  # Get SoC and charge current
  SOC=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0)
  CHARGE_CURRENT=$(( $(cat /sys/class/power_supply/BAT1/current_now 2>/dev/null || echo 0) / 1000 ))
  
  # Check for high temperature events
  HIGH_TEMP_EVENT=""
  [[ "$NVME_TEMP" -gt 35 ]] && HIGH_TEMP_EVENT+=" NVMe"
  [[ "$GPU_TEMP" -gt 35 ]] && HIGH_TEMP_EVENT+=" GPU"
  [[ "$BATTERY_TEMP" -gt 35 ]] && HIGH_TEMP_EVENT+=" Battery"
  [[ "$SYSTEM_TEMP" -gt 35 ]] && HIGH_TEMP_EVENT+=" System"
  
  # Log data to CSV
  echo "$DATE,$NVME_TEMP,$GPU_TEMP,$BATTERY_TEMP,$SYSTEM_TEMP,$SOC,$CHARGE_CURRENT" >> "$OUTPUT_FILE"
  [[ -n "$HIGH_TEMP_EVENT" ]] && echo "$DATE,$HIGH_TEMP_EVENT" >> "$HIGH_TEMP_FILE"
  
  # Check exit conditions
  if [[ "$TARGET_SOC" != "t" && "$SOC" -ge "$TARGET_SOC" ]]; then
    break
  elif [[ "$TARGET_SOC" == "t" && "$(date +%s)" -ge "$END_TIME" ]]; then
    break
  fi
  
  # Wait before next iteration
  sleep "$INTERVAL_SECONDS"
done

echo "Logging complete. Data saved in $OUTPUT_FILE and high temperature events in $HIGH_TEMP_FILE."
