#!/bin/bash
set -e

export FABRIC_CFG_PATH=$PWD/config
export CORE_PEER_TLS_ENABLED=true
ORDERER_CA=$PWD/organizations/ordererOrganizations/example.com/orderers/orderer0.example.com/tls/ca.crt
BATTERY_PKG=battery_1.1:5d41183fa6849581f250e70f42553dbb46f21b93cd5d3245569a607b39ce2166
MOTOR_PKG=motor_1.2:986e3414771de91b3d1e88b4ed6b297e78b907fc42261e1a66e7e1b4e0c41998
CHASSIS_PKG=chassis_1.2:f720bfa0c8926eafc153dab59ebb42f7f5cef0136c813e414573169e5f6a3a0f

echo ""; echo "=== STEP 1: CREATE CHANNELS ==="

export CORE_PEER_LOCALMSPID=BatteryMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer channel create -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c batterychannel -f ./configtx/channel-artifacts/batterychannel.tx \
  --outputBlock ./configtx/channel-artifacts/batterychannel.block --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=MotorMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer channel create -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c motorchannel -f ./configtx/channel-artifacts/motorchannel.tx \
  --outputBlock ./configtx/channel-artifacts/motorchannel.block --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=ChassisMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp
export CORE_PEER_ADDRESS=localhost:10051
peer channel create -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c chassischannel -f ./configtx/channel-artifacts/chassischannel.tx \
  --outputBlock ./configtx/channel-artifacts/chassischannel.block --tls --cafile $ORDERER_CA

echo ""; echo "=== STEP 2: JOIN PEERS ==="

export CORE_PEER_LOCALMSPID=BatteryMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer channel join -b ./configtx/channel-artifacts/batterychannel.block

export CORE_PEER_LOCALMSPID=MotorMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer channel join -b ./configtx/channel-artifacts/motorchannel.block

export CORE_PEER_LOCALMSPID=ChassisMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp
export CORE_PEER_ADDRESS=localhost:10051
peer channel join -b ./configtx/channel-artifacts/chassischannel.block

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:11051
peer channel join -b ./configtx/channel-artifacts/batterychannel.block

export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:12051
peer channel join -b ./configtx/channel-artifacts/motorchannel.block

export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:13051
peer channel join -b ./configtx/channel-artifacts/chassischannel.block

echo ""; echo "=== STEP 3: ANCHOR PEERS ==="

export CORE_PEER_LOCALMSPID=BatteryMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c batterychannel -f ./configtx/channel-artifacts/BatteryMSPanchors.tx --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c batterychannel -f ./configtx/channel-artifacts/VoltRideBatteryanchors.tx --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=MotorMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c motorchannel -f ./configtx/channel-artifacts/MotorMSPanchors.tx --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:12051
peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c motorchannel -f ./configtx/channel-artifacts/VoltRideMotoranchors.tx --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=ChassisMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp
export CORE_PEER_ADDRESS=localhost:10051
peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c chassischannel -f ./configtx/channel-artifacts/ChassisMSPanchors.tx --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:13051
peer channel update -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  -c chassischannel -f ./configtx/channel-artifacts/VoltRideChassisanchors.tx --tls --cafile $ORDERER_CA

echo ""; echo "=== STEP 4: INSTALL CHAINCODE ==="

export CORE_PEER_LOCALMSPID=BatteryMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode install ./chaincode/battery.tar.gz

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
peer lifecycle chaincode install ./chaincode/battery.tar.gz

export CORE_PEER_LOCALMSPID=MotorMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer lifecycle chaincode install ./chaincode/motor.tar.gz

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:12051
peer lifecycle chaincode install ./chaincode/motor.tar.gz

export CORE_PEER_LOCALMSPID=ChassisMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp
export CORE_PEER_ADDRESS=localhost:10051
peer lifecycle chaincode install ./chaincode/chassis.tar.gz

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:13051
peer lifecycle chaincode install ./chaincode/chassis.tar.gz

echo ""; echo "=== STEP 5: APPROVE ==="

export CORE_PEER_LOCALMSPID=BatteryMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID batterychannel --name battery --version 1.1 \
  --package-id $BATTERY_PKG --sequence 1 --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID batterychannel --name battery --version 1.1 \
  --package-id $BATTERY_PKG --sequence 1 --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=MotorMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID motorchannel --name motor --version 1.2 \
  --package-id $MOTOR_PKG --sequence 1 --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:12051
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID motorchannel --name motor --version 1.2 \
  --package-id $MOTOR_PKG --sequence 1 --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=ChassisMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp
export CORE_PEER_ADDRESS=localhost:10051
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID chassischannel --name chassis --version 1.2 \
  --package-id $CHASSIS_PKG --sequence 1 --tls --cafile $ORDERER_CA

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:13051
peer lifecycle chaincode approveformyorg \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID chassischannel --name chassis --version 1.2 \
  --package-id $CHASSIS_PKG --sequence 1 --tls --cafile $ORDERER_CA

echo ""; echo "=== STEP 6: COMMIT ==="

export CORE_PEER_LOCALMSPID=BatteryMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051
peer lifecycle chaincode commit \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID batterychannel --name battery --version 1.1 --sequence 1 \
  --tls --cafile $ORDERER_CA \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt \
  --peerAddresses localhost:11051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt

export CORE_PEER_LOCALMSPID=MotorMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051
peer lifecycle chaincode commit \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID motorchannel --name motor --version 1.2 --sequence 1 \
  --tls --cafile $ORDERER_CA \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt \
  --peerAddresses localhost:12051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt

export CORE_PEER_LOCALMSPID=ChassisMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp
export CORE_PEER_ADDRESS=localhost:10051
peer lifecycle chaincode commit \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --channelID chassischannel --name chassis --version 1.2 --sequence 1 \
  --tls --cafile $ORDERER_CA \
  --peerAddresses localhost:10051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt \
  --peerAddresses localhost:13051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt

echo ""; echo "=== STEP 7: SMOKE TEST ==="
sleep 3

export CORE_PEER_LOCALMSPID=VoltRideMSP
export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=$PWD/organizations/peerOrganizations/voltride.example.com/users/Admin@voltride.example.com/msp
export CORE_PEER_ADDRESS=localhost:11051

peer chaincode invoke \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --tls --cafile $ORDERER_CA -C batterychannel -n battery \
  --peerAddresses localhost:7051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com/tls/ca.crt \
  --peerAddresses localhost:11051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com/tls/ca.crt \
  -c '{"function":"CreateOrder","Args":["BAT-001","100","{\"vehicleModel\":\"VR-S1\"}"]}'
sleep 3
peer chaincode query -C batterychannel -n battery -c '{"function":"GetOrder","Args":["BAT-001"]}'

export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:12051
peer chaincode invoke \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --tls --cafile $ORDERER_CA -C motorchannel -n motor \
  --peerAddresses localhost:9051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com/tls/ca.crt \
  --peerAddresses localhost:12051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com/tls/ca.crt \
  -c '{"function":"CreateOrder","Args":["MOT-001","50","{\"motorType\":\"BLDC\"}"]}'
sleep 3
peer chaincode query -C motorchannel -n motor -c '{"function":"GetOrder","Args":["MOT-001"]}'

export CORE_PEER_TLS_ROOTCERT_FILE=$PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:13051
peer chaincode invoke \
  -o localhost:7050 --ordererTLSHostnameOverride orderer0.example.com \
  --tls --cafile $ORDERER_CA -C chassischannel -n chassis \
  --peerAddresses localhost:10051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com/tls/ca.crt \
  --peerAddresses localhost:13051 \
  --tlsRootCertFiles $PWD/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com/tls/ca.crt \
  -c '{"function":"CreateOrder","Args":["CHS-001","25","{\"chassisType\":\"ScooterFrame\"}"]}'
sleep 3
peer chaincode query -C chassischannel -n chassis -c '{"function":"GetOrder","Args":["CHS-001"]}'

echo ""
echo "============================================="
echo " BLOCKCHAIN LAYER COMPLETE - ALL TESTS DONE"
echo "============================================="
