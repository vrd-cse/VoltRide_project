#!/bin/bash

export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/voltride.example.com/

function enrollVoltrideCAAdmin() {

  mkdir -p organizations/peerOrganizations/voltride.example.com/

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/voltride.example.com/

  fabric-ca-client enroll \
    -u https://admin:adminpw@localhost:7054 \
    --caname ca-voltride \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  cat > ${PWD}/organizations/peerOrganizations/voltride.example.com/msp/config.yaml <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voltride.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voltride.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voltride.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-7054-ca-voltride.pem
    OrganizationalUnitIdentifier: orderer
EOF

}


function registerVoltrideIdentities() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/voltride.example.com/

  # Battery Channel Peer
  fabric-ca-client register \
    --caname ca-voltride \
    --id.name peerbattery \
    --id.secret peerbatterypw \
    --id.type peer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  # Motor Channel Peer
  fabric-ca-client register \
    --caname ca-voltride \
    --id.name peermotor \
    --id.secret peermotorpw \
    --id.type peer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  # Chassis Channel Peer
  fabric-ca-client register \
    --caname ca-voltride \
    --id.name peerchassis \
    --id.secret peerchassispw \
    --id.type peer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  # User
  fabric-ca-client register \
    --caname ca-voltride \
    --id.name user1 \
    --id.secret user1pw \
    --id.type client \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  # Org Admin
  fabric-ca-client register \
    --caname ca-voltride \
    --id.name voltrideadmin \
    --id.secret voltrideadminpw \
    --id.type admin \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem
}


function generateVoltRideBatteryPeer() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/voltride.example.com

  PEER_PATH=${PWD}/organizations/peerOrganizations/voltride.example.com/peers/peerbattery.voltride.example.com

  mkdir -p ${PEER_PATH}

  # Peer MSP
  fabric-ca-client enroll \
    -u https://peerbattery:peerbatterypw@localhost:7054 \
    --caname ca-voltride \
    -M ${PEER_PATH}/msp \
    --csr.hosts peerbattery.voltride.example.com \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/voltride.example.com/msp/config.yaml \
     ${PEER_PATH}/msp/config.yaml

  # TLS MSP
  fabric-ca-client enroll \
    -u https://peerbattery:peerbatterypw@localhost:7054 \
    --caname ca-voltride \
    -M ${PEER_PATH}/tls \
    --enrollment.profile tls \
    --csr.hosts peerbattery.voltride.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  cp ${PEER_PATH}/tls/tlscacerts/* ${PEER_PATH}/tls/ca.crt
  cp ${PEER_PATH}/tls/signcerts/* ${PEER_PATH}/tls/server.crt
  cp ${PEER_PATH}/tls/keystore/* ${PEER_PATH}/tls/server.key
}
function generateVoltRideMotorPeer() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/voltride.example.com

  PEER_PATH=${PWD}/organizations/peerOrganizations/voltride.example.com/peers/peermotor.voltride.example.com

  mkdir -p ${PEER_PATH}

  # Peer MSP
  fabric-ca-client enroll \
    -u https://peermotor:peermotorpw@localhost:7054 \
    --caname ca-voltride \
    -M ${PEER_PATH}/msp \
    --csr.hosts peermotor.voltride.example.com \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/voltride.example.com/msp/config.yaml \
     ${PEER_PATH}/msp/config.yaml

  # TLS MSP
  fabric-ca-client enroll \
    -u https://peermotor:peermotorpw@localhost:7054 \
    --caname ca-voltride \
    -M ${PEER_PATH}/tls \
    --enrollment.profile tls \
    --csr.hosts peermotor.voltride.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  cp ${PEER_PATH}/tls/tlscacerts/* ${PEER_PATH}/tls/ca.crt
  cp ${PEER_PATH}/tls/signcerts/* ${PEER_PATH}/tls/server.crt
  cp ${PEER_PATH}/tls/keystore/* ${PEER_PATH}/tls/server.key
}

function generateVoltRideChassisPeer() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/voltride.example.com

  PEER_PATH=${PWD}/organizations/peerOrganizations/voltride.example.com/peers/peerchassis.voltride.example.com

  mkdir -p ${PEER_PATH}

  # Peer MSP
  fabric-ca-client enroll \
    -u https://peerchassis:peerchassispw@localhost:7054 \
    --caname ca-voltride \
    -M ${PEER_PATH}/msp \
    --csr.hosts peerchassis.voltride.example.com \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/voltride.example.com/msp/config.yaml \
     ${PEER_PATH}/msp/config.yaml

  # TLS MSP
  fabric-ca-client enroll \
    -u https://peerchassis:peerchassispw@localhost:7054 \
    --caname ca-voltride \
    -M ${PEER_PATH}/tls \
    --enrollment.profile tls \
    --csr.hosts peerchassis.voltride.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/voltride/tls-cert.pem

  cp ${PEER_PATH}/tls/tlscacerts/* ${PEER_PATH}/tls/ca.crt
  cp ${PEER_PATH}/tls/signcerts/* ${PEER_PATH}/tls/server.crt
  cp ${PEER_PATH}/tls/keystore/* ${PEER_PATH}/tls/server.key
}

#################################################################################################################

# Battery organization Registration -->
function enrollBatteryCAAdmin() {

  mkdir -p organizations/peerOrganizations/battery.example.com

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/battery.example.com

  fabric-ca-client enroll \
    -u https://admin:adminpw@localhost:8054 \
    --caname ca-battery \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem

  cat > ${PWD}/organizations/peerOrganizations/battery.example.com/msp/config.yaml <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-battery.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-battery.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-battery.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-8054-ca-battery.pem
    OrganizationalUnitIdentifier: orderer
EOF

}


function registerBatteryIdentities() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/battery.example.com

  # Battery Peer
  fabric-ca-client register \
    --caname ca-battery \
    --id.name peer0 \
    --id.secret peer0pw \
    --id.type peer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem

  # User
  fabric-ca-client register \
    --caname ca-battery \
    --id.name user1 \
    --id.secret user1pw \
    --id.type client \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem

  # Org Admin
  fabric-ca-client register \
    --caname ca-battery \
    --id.name batteryadmin \
    --id.secret batteryadminpw \
    --id.type admin \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem
}


function generateBatteryPeer0() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/battery.example.com

  PEER_PATH=${PWD}/organizations/peerOrganizations/battery.example.com/peers/peer0.battery.example.com

  mkdir -p ${PEER_PATH}

  echo "Generating Battery Peer MSP"

  # MSP Enrollment
  fabric-ca-client enroll \
    -u https://peer0:peer0pw@localhost:8054 \
    --caname ca-battery \
    -M ${PEER_PATH}/msp \
    --csr.hosts peer0.battery.example.com \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/battery.example.com/msp/config.yaml \
     ${PEER_PATH}/msp/config.yaml

  echo "Generating Battery Peer TLS"

  # TLS Enrollment
  fabric-ca-client enroll \
    -u https://peer0:peer0pw@localhost:8054 \
    --caname ca-battery \
    -M ${PEER_PATH}/tls \
    --enrollment.profile tls \
    --csr.hosts peer0.battery.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem

  cp ${PEER_PATH}/tls/tlscacerts/* ${PEER_PATH}/tls/ca.crt
  cp ${PEER_PATH}/tls/signcerts/* ${PEER_PATH}/tls/server.crt
  cp ${PEER_PATH}/tls/keystore/* ${PEER_PATH}/tls/server.key
}

function generateBatteryUsers() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/battery.example.com

  # User1 MSP
  fabric-ca-client enroll \
    -u https://user1:user1pw@localhost:8054 \
    --caname ca-battery \
    -M ${PWD}/organizations/peerOrganizations/battery.example.com/users/User1@battery.example.com/msp \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/battery.example.com/msp/config.yaml \
     ${PWD}/organizations/peerOrganizations/battery.example.com/users/User1@battery.example.com/msp/config.yaml

  # Admin MSP
  fabric-ca-client enroll \
    -u https://batteryadmin:batteryadminpw@localhost:8054 \
    --caname ca-battery \
    -M ${PWD}/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp \
    --tls.certfiles ${PWD}/organizations/fabric-ca/battery/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/battery.example.com/msp/config.yaml \
     ${PWD}/organizations/peerOrganizations/battery.example.com/users/Admin@battery.example.com/msp/config.yaml
}


####################################################################################################################




# Motor Organisation Registration -->

function enrollMotorCAAdmin() {

  mkdir -p organizations/peerOrganizations/motor.example.com

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/motor.example.com

  fabric-ca-client enroll \
    -u https://admin:adminpw@localhost:9054 \
    --caname ca-motor \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem

  cat > ${PWD}/organizations/peerOrganizations/motor.example.com/msp/config.yaml <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-motor.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-motor.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-motor.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-9054-ca-motor.pem
    OrganizationalUnitIdentifier: orderer
EOF

}


function registerMotorIdentities() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/motor.example.com

  # Battery Peer
  fabric-ca-client register \
    --caname ca-motor \
    --id.name peer0 \
    --id.secret peer0pw \
    --id.type peer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem

  # User
  fabric-ca-client register \
    --caname ca-motor \
    --id.name user1 \
    --id.secret user1pw \
    --id.type client \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem

  # Org Admin
  fabric-ca-client register \
    --caname ca-motor \
    --id.name motoradmin \
    --id.secret motoradminpw \
    --id.type admin \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem
}


function generateMotorPeer0() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/motor.example.com

  PEER_PATH=${PWD}/organizations/peerOrganizations/motor.example.com/peers/peer0.motor.example.com

  mkdir -p ${PEER_PATH}

  echo "Generating Motor Peer MSP"

  # MSP Enrollment
  fabric-ca-client enroll \
    -u https://peer0:peer0pw@localhost:9054 \
    --caname ca-motor \
    -M ${PEER_PATH}/msp \
    --csr.hosts peer0.motor.example.com \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/motor.example.com/msp/config.yaml \
     ${PEER_PATH}/msp/config.yaml

  echo "Generating Motor Peer TLS"

  # TLS Enrollment
  fabric-ca-client enroll \
    -u https://peer0:peer0pw@localhost:9054 \
    --caname ca-motor \
    -M ${PEER_PATH}/tls \
    --enrollment.profile tls \
    --csr.hosts peer0.motor.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem

  cp ${PEER_PATH}/tls/tlscacerts/* ${PEER_PATH}/tls/ca.crt
  cp ${PEER_PATH}/tls/signcerts/* ${PEER_PATH}/tls/server.crt
  cp ${PEER_PATH}/tls/keystore/* ${PEER_PATH}/tls/server.key
}



function generateMotorUsers() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/motor.example.com

  # User1 MSP
  fabric-ca-client enroll \
    -u https://user1:user1pw@localhost:9054 \
    --caname ca-motor \
    -M ${PWD}/organizations/peerOrganizations/motor.example.com/users/User1@motor.example.com/msp \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/motor.example.com/msp/config.yaml \
     ${PWD}/organizations/peerOrganizations/motor.example.com/users/User1@motor.example.com/msp/config.yaml

  # Admin MSP
  fabric-ca-client enroll \
    -u https://motoradmin:motoradminpw@localhost:9054 \
    --caname ca-motor \
    -M ${PWD}/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp \
    --tls.certfiles ${PWD}/organizations/fabric-ca/motor/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/motor.example.com/msp/config.yaml \
     ${PWD}/organizations/peerOrganizations/motor.example.com/users/Admin@motor.example.com/msp/config.yaml
}


##################################################################################################################


# Chassis Organization Registration-->

function enrollChassisCAAdmin() {

  mkdir -p organizations/peerOrganizations/chassis.example.com

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/chassis.example.com

  fabric-ca-client enroll \
    -u https://admin:adminpw@localhost:10054 \
    --caname ca-chassis \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem

  cat > ${PWD}/organizations/peerOrganizations/chassis.example.com/msp/config.yaml <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/localhost-10054-ca-chassis.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/localhost-10054-ca-chassis.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/localhost-10054-ca-chassis.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/localhost-10054-ca-chassis.pem
    OrganizationalUnitIdentifier: orderer
EOF

}


function registerChassisIdentities() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/chassis.example.com

  # Battery Peer
  fabric-ca-client register \
    --caname ca-chassis \
    --id.name peer0 \
    --id.secret peer0pw \
    --id.type peer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem

  # User
  fabric-ca-client register \
    --caname ca-chassis \
    --id.name user1 \
    --id.secret user1pw \
    --id.type client \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem

  # Org Admin
  fabric-ca-client register \
    --caname ca-chassis \
    --id.name chassisadmin \
    --id.secret chassisadminpw \
    --id.type admin \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem
}


function generateChassisPeer0() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/chassis.example.com

  PEER_PATH=${PWD}/organizations/peerOrganizations/chassis.example.com/peers/peer0.chassis.example.com

  mkdir -p ${PEER_PATH}

  echo "Generating Chassis Peer MSP"

  # MSP Enrollment
  fabric-ca-client enroll \
    -u https://peer0:peer0pw@localhost:10054 \
    --caname ca-chassis \
    -M ${PEER_PATH}/msp \
    --csr.hosts peer0.chassis.example.com \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/chassis.example.com/msp/config.yaml \
     ${PEER_PATH}/msp/config.yaml

  echo "Generating Chassis Peer TLS"

  # Clean old TLS material
  rm -rf ${PEER_PATH}/tls
  mkdir -p ${PEER_PATH}/tls

  # TLS Enrollment
  fabric-ca-client enroll \
    -u https://peer0:peer0pw@localhost:10054 \
    --caname ca-chassis \
    -M ${PEER_PATH}/tls \
    --enrollment.profile tls \
    --csr.hosts peer0.chassis.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem

  rm -f ${PEER_PATH}/tls/server.key
  rm -f ${PEER_PATH}/tls/server.crt
  rm -f ${PEER_PATH}/tls/ca.crt

  cp ${PEER_PATH}/tls/tlscacerts/* ${PEER_PATH}/tls/ca.crt
  cp ${PEER_PATH}/tls/signcerts/* ${PEER_PATH}/tls/server.crt

  KEY_FILE=$(ls ${PEER_PATH}/tls/keystore/*_sk)
  cp "$KEY_FILE" ${PEER_PATH}/tls/server.key
}


function generateChassisUsers() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/peerOrganizations/chassis.example.com

  # User1 MSP
  fabric-ca-client enroll \
    -u https://user1:user1pw@localhost:10054 \
    --caname ca-chassis \
    -M ${PWD}/organizations/peerOrganizations/chassis.example.com/users/User1@chassis.example.com/msp \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/chassis.example.com/msp/config.yaml \
     ${PWD}/organizations/peerOrganizations/chassis.example.com/users/User1@chassis.example.com/msp/config.yaml

  # Admin MSP
  fabric-ca-client enroll \
    -u https://chassisadmin:chassisadminpw@localhost:10054 \
    --caname ca-chassis \
    -M ${PWD}/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp \
    --tls.certfiles ${PWD}/organizations/fabric-ca/chassis/tls-cert.pem

  cp ${PWD}/organizations/peerOrganizations/chassis.example.com/msp/config.yaml \
     ${PWD}/organizations/peerOrganizations/chassis.example.com/users/Admin@chassis.example.com/msp/config.yaml
}


#################################################################################################################

# =========================================================
# ORDERER ORGANIZATION
# =========================================================

function enrollOrdererCAAdmin() {

  mkdir -p organizations/ordererOrganizations/example.com

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

  # Enroll CA Admin
  fabric-ca-client enroll \
    -u https://admin:adminpw@localhost:11054 \
    --caname ca-orderer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem

  # Create NodeOUs config
  cat > ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml <<EOF
NodeOUs:
  Enable: true

  ClientOUIdentifier:
    Certificate: cacerts/localhost-11054-ca-orderer.pem
    OrganizationalUnitIdentifier: client

  AdminOUIdentifier:
    Certificate: cacerts/localhost-11054-ca-orderer.pem
    OrganizationalUnitIdentifier: admin

  OrdererOUIdentifier:
    Certificate: cacerts/localhost-11054-ca-orderer.pem
    OrganizationalUnitIdentifier: orderer
EOF
}

# =========================================================
# REGISTER ORDERER IDENTITIES
# =========================================================

function registerOrdererIdentities() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

  # Register Orderer Node
  fabric-ca-client register \
    --caname ca-orderer \
    --id.name orderer0 \
    --id.secret orderer0pw \
    --id.type orderer \
    --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem

  # Register Orderer Admin
  fabric-ca-client register \
    --caname ca-orderer \
    --id.name ordereradmin \
    --id.secret ordereradminpw \
    --id.type admin \
    --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem
}

# =========================================================
# GENERATE ORDERER MSP + TLS
# =========================================================

function generateOrderer() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

  ORDERER_PATH=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer0.example.com

  mkdir -p ${ORDERER_PATH}

  echo "Generating Orderer MSP"

  # MSP Enrollment
  fabric-ca-client enroll \
    -u https://orderer0:orderer0pw@localhost:11054 \
    --caname ca-orderer \
    -M ${ORDERER_PATH}/msp \
    --csr.hosts orderer0.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem

  cp ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml \
     ${ORDERER_PATH}/msp/config.yaml

  echo "Generating Orderer TLS"

  # TLS Enrollment
  fabric-ca-client enroll \
    -u https://orderer0:orderer0pw@localhost:11054 \
    --caname ca-orderer \
    -M ${ORDERER_PATH}/tls \
    --enrollment.profile tls \
    --csr.hosts orderer0.example.com \
    --csr.hosts localhost \
    --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem

  # Cleanup old files
  rm -f ${ORDERER_PATH}/tls/ca.crt
  rm -f ${ORDERER_PATH}/tls/server.crt
  rm -f ${ORDERER_PATH}/tls/server.key

  # Copy TLS certs
  cp ${ORDERER_PATH}/tls/tlscacerts/* \
     ${ORDERER_PATH}/tls/ca.crt

  cp ${ORDERER_PATH}/tls/signcerts/* \
     ${ORDERER_PATH}/tls/server.crt

  cp ${ORDERER_PATH}/tls/keystore/*_sk \
     ${ORDERER_PATH}/tls/server.key
}

# =========================================================
# GENERATE ORDERER ADMIN
# =========================================================

function generateOrdererAdmin() {

  export FABRIC_CA_CLIENT_HOME=${PWD}/organizations/ordererOrganizations/example.com

  mkdir -p ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com

  echo "Generating Orderer Admin MSP"

  # Admin Enrollment
  fabric-ca-client enroll \
    -u https://ordereradmin:ordereradminpw@localhost:11054 \
    --caname ca-orderer \
    -M ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp \
    --tls.certfiles ${PWD}/organizations/fabric-ca/orderer/tls-cert.pem

  cp ${PWD}/organizations/ordererOrganizations/example.com/msp/config.yaml \
     ${PWD}/organizations/ordererOrganizations/example.com/users/Admin@example.com/msp/config.yaml
}
