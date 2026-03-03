#!/bin/bash
# Add a custom service filter to Logwatch
set -e

SERVICE=""
LOGFILE=""
PATTERN=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --service) SERVICE="$2"; shift 2 ;;
    --logfile) LOGFILE="$2"; shift 2 ;;
    --pattern) PATTERN="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: add-filter.sh --service NAME --logfile PATH [--pattern REGEX]"
      echo ""
      echo "Creates a custom Logwatch service filter for application logs."
      echo ""
      echo "Options:"
      echo "  --service NAME    Service name (e.g., myapp)"
      echo "  --logfile PATH    Log file path (e.g., /var/log/myapp.log)"
      echo "  --pattern REGEX   Optional grep pattern to filter lines"
      echo ""
      echo "Example:"
      echo "  add-filter.sh --service myapp --logfile /var/log/myapp.log --pattern 'ERROR|WARN'"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$SERVICE" || -z "$LOGFILE" ]]; then
  echo "❌ --service and --logfile are required"
  exit 1
fi

# Create logfile group config
LOGFILE_CONF="/etc/logwatch/conf/logfiles/${SERVICE}.conf"
sudo mkdir -p /etc/logwatch/conf/logfiles
cat <<EOF | sudo tee "$LOGFILE_CONF" > /dev/null
# Logfile group for $SERVICE
LogFile = $LOGFILE
Archive = ${LOGFILE}.*.gz
EOF

echo "✅ Created logfile config: $LOGFILE_CONF"

# Create service filter script
SERVICE_SCRIPT="/etc/logwatch/scripts/services/${SERVICE}"
sudo mkdir -p /etc/logwatch/scripts/services

if [[ -n "$PATTERN" ]]; then
  cat <<'SCRIPT_EOF' | sed "s|__PATTERN__|$PATTERN|g" | sed "s|__SERVICE__|$SERVICE|g" | sudo tee "$SERVICE_SCRIPT" > /dev/null
#!/usr/bin/perl
# Custom Logwatch service script for __SERVICE__

my $pattern = qr/__PATTERN__/;
my %counts;

while (defined(my $line = <STDIN>)) {
  chomp $line;
  if ($line =~ $pattern) {
    my ($match) = $line =~ /($pattern)/;
    $counts{$match}++;
  }
}

if (keys %counts) {
  print "\n ----- __SERVICE__ Log Summary -----\n";
  foreach my $key (sort keys %counts) {
    printf "   %-20s : %d times\n", $key, $counts{$key};
  }
  print "\n";
}
SCRIPT_EOF
else
  cat <<'SCRIPT_EOF' | sed "s|__SERVICE__|$SERVICE|g" | sudo tee "$SERVICE_SCRIPT" > /dev/null
#!/usr/bin/perl
# Custom Logwatch service script for __SERVICE__

my $count = 0;
while (defined(my $line = <STDIN>)) {
  $count++;
}
if ($count) {
  print "\n ----- __SERVICE__ -----\n";
  print "   Total log entries: $count\n\n";
}
SCRIPT_EOF
fi

sudo chmod +x "$SERVICE_SCRIPT"
echo "✅ Created service script: $SERVICE_SCRIPT"

# Create service config
SERVICE_CONF="/etc/logwatch/conf/services/${SERVICE}.conf"
sudo mkdir -p /etc/logwatch/conf/services
cat <<EOF | sudo tee "$SERVICE_CONF" > /dev/null
# Service definition for $SERVICE
Title = "$SERVICE"
LogFile = $SERVICE
EOF

echo "✅ Created service config: $SERVICE_CONF"
echo ""
echo "Test it: logwatch --service $SERVICE --detail high --range today"
