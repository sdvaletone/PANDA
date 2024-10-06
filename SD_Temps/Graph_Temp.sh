for i in {1..90}; do sensors | awk -v date="$(date +"%Y-%m-%d %H:%M:%S")" '/^Package id 0:/ {print date "," $4}' >> temperature_log.csv; sleep 10; done
