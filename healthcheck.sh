#!/usr/bin/env bash

#set -x  # Print commands
set -e  # Exit on errors

# Check nginx config is valid
echo "Checking nginx configuration..."
nginx -t

# Check supervisor running
echo "Checking supervisor..."
# Need to do "|| exit 1" here since "set -e" apparently does not care about tests.
[[ -f /run/supervisord.pid ]] || exit 1

# Check supervisor controlled services
# Since "supervisorctl status" is heavy and the healthcheck runs quit often, we use "ps" here
echo "Checking supervisor services..."
pslist=$(ps)
echo ${pslist} | grep docker-gen >/dev/null
echo ${pslist} | grep "nginx: master process" >/dev/null
echo ${pslist} | grep "nginx: worker process" >/dev/null
echo ${pslist} | grep crond >/dev/null
