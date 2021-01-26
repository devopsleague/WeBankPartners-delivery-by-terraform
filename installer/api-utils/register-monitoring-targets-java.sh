#!/bin/bash

set -e
set -o pipefail

SYS_SETTINGS_ENV_FILE=$1
source $SYS_SETTINGS_ENV_FILE

SCRIPT_DIR=$(dirname "$0")

[ -z "${ACCESS_TOKEN}" ] && ACCESS_TOKEN=$(${SCRIPT_DIR}/login.sh ${SYS_SETTINGS_ENV_FILE})

read -d '' TARGET_INPUTS <<-EOF || true
    {
      "callbackParameter": "1",
      "instance": "platform-core",
      "instance_ip": "${CORE_HOST}",
      "port": "${WECUBE_SERVER_JMX_PORT}",
      "group": "default_java_group"
    }
EOF

INSTALLED_PLUGIN_PKGS=$(ACCESS_TOKEN="$ACCESS_TOKEN" $SCRIPT_DIR/get-plugin-packages.sh $SYS_SETTINGS_ENV_FILE)
jq -r '.[] | select(contains({name: "wecmdb"}) or contains({name: "service-mgmt"})) | .id' <<<"$INSTALLED_PLUGIN_PKGS" | \
	while read -r PLUGIN_PKG_ID; do
		INSTANCE_IDS=$(curl -sSfL \
			--request GET "http://${CORE_HOST}:19090/platform/v1/packages/${PLUGIN_PKG_ID}/instances" \
			--header "Authorization: Bearer ${ACCESS_TOKEN}" \
			| ${SCRIPT_DIR}/check-status-in-json.sh \
			| jq --exit-status -r '[.data[] | .id] | join(" ")'
		)

		for INSTANCE_ID in $INSTANCE_IDS; do
			PARTS=${INSTANCE_ID#*__}
			INSTANCE_IP=${PARTS%__*}
			INSTSNCE_PORT=${PARTS#*__}
			INSTANCE_JMX_PORT=$(( $INSTSNCE_PORT + 10000 ))
			# read -d '' TARGET_INPUTS <<-EOF || true
			# 	${TARGET_INPUTS}
			# 	,
			#     {
			#       "callbackParameter": "1",
			#       "instance": "${INSTANCE_ID}",
			#       "instance_ip": "${INSTANCE_IP}",
			#       "port": "${INSTANCE_JMX_PORT}",
			#       "group": "default_java_group"
			#     }
			# EOF
		done
	done

curl -sSfL \
	--request POST "http://${CORE_HOST}:19090/monitor/api/v1/agent/export/register/java" \
	--header "Authorization: Bearer ${ACCESS_TOKEN}" \
	--header 'Content-Type: application/json' \
	--data @- <<-EOF \
	| ${SCRIPT_DIR}/check-status-in-json.sh '.resultCode == "0"'
		{
		  "requestId": "1",
		  "inputs": [
		${TARGET_INPUTS}
		  ]
		}
	EOF
