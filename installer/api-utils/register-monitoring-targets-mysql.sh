#!/bin/bash

set -e
set -o pipefail

SYS_SETTINGS_ENV_FILE=$1
source $SYS_SETTINGS_ENV_FILE

SCRIPT_DIR=$(dirname "$0")

[ -z "${ACCESS_TOKEN}" ] && ACCESS_TOKEN=$(${SCRIPT_DIR}/login.sh ${SYS_SETTINGS_ENV_FILE})

ACCESS_TOKEN="${ACCESS_TOKEN}" ${SCRIPT_DIR}/register-monitoring-target.sh \
	${SYS_SETTINGS_ENV_FILE} <<-EOF
		{
		    "type": "mysql",
		    "name": "plugin_mysql1",
		    "ip": "${PLUGIN_DB_HOST}",
		    "port": "${PLUGIN_DB_PORT}",
		    "user": "${PLUGIN_DB_USERNAME}",
		    "password": "${PLUGIN_DB_PASSWORD}",
		    "agent_manager": true,
		    "exporter": false
		}
	EOF
