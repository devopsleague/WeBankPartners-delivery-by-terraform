#!/bin/bash

set -e

WECUBE_HOST=$1
COLLECTION_DIR=$2
PLUGIN_PKG_DIR=$3
MYSQL_PASSWORD=$4
PLUGIN_HOST=$5
WECUBE_HOST2=$6


echo -e "\nRegistering plugins, this may take a few minutes...\n"
docker run --rm -t \
    -v "$COLLECTION_DIR:$COLLECTION_DIR" \
    -v "$PLUGIN_PKG_DIR:$PLUGIN_PKG_DIR" \
    ccr.ccs.tencentyun.com/webankpartners/newman \
    run "$COLLECTION_DIR/020_wecube_plugin_register.postman_collection.json" \
    --env-var "domain=$WECUBE_HOST:19090" \
    --env-var "username=umadmin" \
    --env-var "password=umadmin" \
    --env-var "wecube_host=$WECUBE_HOST" \
    --env-var "plugin_host=$PLUGIN_HOST" \
    -d "$PLUGIN_PKG_DIR/plugin-list.csv" \
    --delay-request 2000 --disable-unicode \
    --reporters cli \
    --reporter-cli-no-banner --reporter-cli-no-console

echo -e "\nConfiguring plugin WeCMDB...\n"
docker run --rm -t \
    -v "$COLLECTION_DIR:$COLLECTION_DIR" \
    -v "$PLUGIN_PKG_DIR:$PLUGIN_PKG_DIR" \
    ccr.ccs.tencentyun.com/webankpartners/newman \
    run "$COLLECTION_DIR/022_wecube_sync_model.postman_collection.json" \
    --env-var "domain=$WECUBE_HOST:19090" \
    --env-var "username=umadmin" \
    --env-var "password=umadmin" \
    --env-var "wecube_host=$WECUBE_HOST" \
    --env-var "plugin_host=$PLUGIN_HOST" \
    --delay-request 2000 --disable-unicode \
    --reporters cli \
    --reporter-cli-no-banner --reporter-cli-no-console

echo -e "\nConfiguring plugin Open-Monitor...\n"
echo "Fetching monitor agent package..."
MONITOR_AGENT_URL="https://wecube-plugins-1259008868.cos.ap-guangzhou.myqcloud.com/node_exporter_v2.1.tar.gz"
MONITOR_AGENT_PKG_FILE="$PLUGIN_PKG_DIR/node_exporter_v2.1.tar.gz"
MONITOR_AGENT_PORT=9100
curl -L $MONITOR_AGENT_URL -o $MONITOR_AGENT_PKG_FILE
tar xzf $MONITOR_AGENT_PKG_FILE -C $PLUGIN_PKG_DIR
pushd "$PLUGIN_PKG_DIR/node_exporter_v2.1" >/dev/null

WECUBE_S3_URL1='http://'${WECUBE_HOST}':9000'
WECUBE_S3_URL2='http://'${WECUBE_HOST2}':9000'
docker run --name minio-client-upload1 -v /data/wecube/installer/wecube-plugin-installer/plugins:/plugins -itd --entrypoint=/bin/sh minio/mc
docker exec minio-client-upload1 mc config host add wecubeS3 $WECUBE_S3_URL1 'access_key' 'secret_key' 
docker exec minio-client-upload1 mc mb wecubeS3/wecube-agent
docker exec minio-client-upload1 mc cp /plugins/node_exporter_v2.1.tar.gz wecubeS3/wecube-agent
docker rm -f minio-client-upload1

docker run --name minio-client-upload2 -v /data/wecube/installer/wecube-plugin-installer/plugins:/plugins -itd --entrypoint=/bin/sh minio/mc
docker exec minio-client-upload2 mc config host add wecubeS3 $WECUBE_S3_URL2 'access_key' 'secret_key' 
docker exec minio-client-upload2 mc mb wecubeS3/wecube-agent
docker exec minio-client-upload2 mc cp /plugins/node_exporter_v2.1.tar.gz wecubeS3/wecube-agent
docker rm -f minio-client-upload2