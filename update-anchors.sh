#!/bin/bash
# =============================================================
# VoltRide Network — Anchor Peer Update Script
# =============================================================

set -e

ORDERER_CA=$PWD/organizations/ordererOrganizations/example.com/orderers/orderer0.example.com/tls/ca.crt
ORDERER_ADDRESS=localhost:7050
ARTIFACTS=$PWD/configtx/channel-artifacts

export FABRIC_CFG_PATH=$PWD/config
export CORE_PEER_TLS_ENABLED=true

build_anchor_envelope() {
  local CHANNEL=$1
  local MSP_ID=$2
  local ANCHOR_HOST=$3
  local ANCHOR_PORT=$4

  echo "  >> Building anchor envelope for ${MSP_ID} on ${CHANNEL}"

  peer channel fetch config ${ARTIFACTS}/${CHANNEL}_config_block.pb \
    -o $ORDERER_ADDRESS \
    --ordererTLSHostnameOverride orderer0.example.com \
    -c $CHANNEL \
    --tls --cafile $ORDERER_CA 2>/dev/null

  configtxlator proto_decode \
    --input ${ARTIFACTS}/${CHANNEL}_config_block.pb \
    --type common.Block \
    --output ${ARTIFACTS}/${CHANNEL}_config_block.json

  jq .data.data[0].payload.data.config \
    ${ARTIFACTS}/${CHANNEL}_config_block.json \
    > ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_config.json

  # Inject anchor peer — no mod_policy, let Fabric inherit it
  jq --arg MSP_ID "$MSP_ID" \
     --arg HOST "$ANCHOR_HOST" \
     --argjson PORT "$ANCHOR_PORT" \
    '.channel_group.groups.Application.groups[$MSP_ID].values.AnchorPeers = {
      "mod_policy": "Admins",
      "value": {
        "anchor_peers": [{"host": $HOST, "port": $PORT}]
      },
      "version": "0"
    }' \
    ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_config.json \
    > ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_modified_config.json

  configtxlator proto_encode \
    --input ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_config.json \
    --type common.Config \
    --output ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_config.pb

  configtxlator proto_encode \
    --input ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_modified_config.json \
    --type common.Config \
    --output ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_modified_config.pb

  configtxlator compute_update \
    --channel_id $CHANNEL \
    --original ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_config.pb \
    --updated ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_modified_config.pb \
    --output ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_anchor_update.pb

  echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'","type":2}},"data":{"config_update":'$(configtxlator proto_decode --input ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_anchor_update.pb --type common.ConfigUpdate)'}}}' \
    | jq . > ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_anchor_envelope.json

  configtxlator proto_encode \
    --input ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_anchor_envelope.json \
    --type common.Envelope \
    --output ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_anchor_envelope.pb
}

update_anchor() {
  local CHANNEL=$1
  local MSP_ID=$2
  local PEER_ADDRESS=$3
  local TLS_ROOTCERT=$4
  local ADMIN_MSP=$5
  local ANCHOR_HOST=$6
  local ANCHOR_PORT=$7
  local OTHER_MSP_ID=$8
  local OTHER_TLS_ROOTCERT=$9
  local OTHER_ADMIN_MSP=${10}
  local OTHER_PEER_ADDRESS=${11}

  echo ""
  echo ">>> Updating anchor peer for ${MSP_ID} on ${CHANNEL}"

  export CORE_PEER_LOCALMSPID=$MSP_ID
  export CORE_PEER_ADDRESS=$PEER_ADDRESS
  export CORE_PEER_TLS_ROOTCERT_FILE=$TLS_ROOTCERT
  export CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP

  build_anchor_envelope $CHANNEL $MSP_ID $ANCHOR_HOST $ANCHOR_PORT

  echo "  >> Signing with ${MSP_ID}"
  export CORE_PEER_LOCALMSPID=$MSP_ID
  export CORE_PEER_ADDRESS=$PEER_ADDRESS
  export CORE_PEER_TLS_ROOTCERT_FILE=$TLS_ROOTCERT
  export CORE_PEER_MSPCONFIGPATH=$ADMIN_MSP
  peer channel signconfigtx \
    -f ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_anchor_envelope.pb

  echo "  >> Signing with ${OTHER_MSP_ID} and submitting"
  export CORE_PEER_LOCALMSPID=$OTHER_MSP_ID
  export CORE_PEER_ADDRESS=$OTHER_PEER_ADDRESS
  export CORE_PEER_TLS_ROOTCERT_FILE=$OTHER_TLS_ROOTCERT
  export CORE_PEER_MSPCONFIGPATH=$OTHER_ADMIN_MSP

  peer channel update \
    -o $ORDERER_ADDRESS \
    --ordererTLSHostnameOverride orderer0.example.com \
    -c $CHANNEL \
    -f ${ARTIFACTS}/${CHANNEL}_${MSP_ID}_anchor_envelope.pb \
    --tls --cafile $ORDERER_CA

  echo ">>> SUCCESS: Anchor peer updated for ${MSP_ID} on ${CHANNEL}"
}

# batterychannel — BatteryMSP anchor
update_anchor \
  "batterychannel" "BatteryMSP" "localhost:7051" \
  "$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp" \
  "peer0.battery.example.com" 7051 \
  "VoltRideMSP" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp" \
  "localhost:11051"

# batterychannel — VoltRideMSP anchor
update_anchor \
  "batterychannel" "VoltRideMSP" "localhost:11051" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp" \
  "peerbattery.voltride.example.com" 11051 \
  "BatteryMSP" \
  "$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp" \
  "localhost:7051"

# motorchannel — MotorMSP anchor
update_anchor \
  "motorchannel" "MotorMSP" "localhost:9051" \
  "$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp" \
  "peer0.motor.example.com" 9051 \
  "VoltRideMSP" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp" \
  "localhost:12051"

# motorchannel — VoltRideMSP anchor
update_anchor \
  "motorchannel" "VoltRideMSP" "localhost:12051" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp" \
  "peermotor.voltride.example.com" 12051 \
  "MotorMSP" \
  "$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp" \
  "localhost:9051"

# chassischannel — ChassisMSP anchor
update_anchor \
  "chassischannel" "ChassisMSP" "localhost:10051" \
  "$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp" \
  "peer0.chassis.example.com" 10051 \
  "VoltRideMSP" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp" \
  "localhost:13051"

# chassischannel — VoltRideMSP anchor
update_anchor \
  "chassischannel" "VoltRideMSP" "localhost:13051" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp" \
  "peerchassis.voltride.example.com" 13051 \
  "ChassisMSP" \
  "$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt" \
  "$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp" \
  "localhost:10051"

echo ""
echo "============================================="
echo " All anchor peers updated successfully!"
echo "============================================="
