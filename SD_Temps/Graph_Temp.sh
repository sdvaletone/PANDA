#!/bin/bash

# File to save the temperature logs
OUTPUT_FILE="temperature_log.csv"

# Total duration in minutes and logging interval in seconds
DURATION_MINUTES=15
INTERVAL_SECONDS=10
ITERATIONS=$((DURATION_MINUTES * 60 / INTERVAL_SECONDS))

# Check if sensors command is available
if ! command -v sensors &> /dev/null; then
  echo "sensors command not found. Please install lm-sensors."
  exit 1
fi

# Log header to CSV
echo "Timestamp,Temperature" > "$OUTPUT_FILE"

# Start message
echo "Starting temperature logging for $DURATION_MINUTES minutes. Data will be saved in $OUTPUT_FILE."

# Log temperature with a countdown message every minute
for ((i=1; i<=ITERATIONS; i++)); do
  # Capture date and temperature, customize "Package id 0" as needed
  DATE="$(date +"%Y-%m-%d %H:%M:%S")"
  TEMP=$(sensors | awk '/^Package id 0:/ {print $4}')

  # Check if temperature was captured
  if [ -n "$TEMP" ]; then
    echo "$DATE,$TEMP" >> "$OUTPUT_FILE"
  else
    echo "$DATE,Temperature not found" >> "$OUTPUT_FILE"
  fi

  # Countdown message every 6 iterations (1 minute)
  if (( i % 6 == 0 )); then
    MINUTES_LEFT=$((DURATION_MINUTES - i * INTERVAL_SECONDS / 60))
    echo "$MINUTES_LEFT minute(s) remaining..."
  fi

  # Wait for the specified interval
  sleep "$INTERVAL_SECONDS"
done

echo "Temperature logging complete. Data saved in $OUTPUT_FILE."
