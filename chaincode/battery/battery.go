package main

import (
	"encoding/json"
	"fmt"
	"regexp"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ============================================================
// Constants
// ============================================================

const (
	StatusPending   = "PENDING"
	StatusFulfilled = "FULFILLED"
	StatusAccepted  = "ACCEPTED"
	StatusRejected  = "REJECTED"
	StatusCancelled = "CANCELLED"

	VoltRideMSP = "VoltRideMSP"
	BatteryMSP  = "BatteryMSP"
)

// ============================================================
// Asset Definitions
// ============================================================

// BatteryQCParams holds the 6 QC parameters measured by BatteryOrg.
// These are also the public inputs to the ZK proof circuit.
type BatteryQCParams struct {
	NominalVoltage        float64 `json:"nominalVoltage"`        // Volts (e.g. 3.7)
	InternalResistance    float64 `json:"internalResistance"`    // mΩ  (e.g. 25.0)
	Capacity              float64 `json:"capacity"`              // Ah  (e.g. 50.0)
	SOH                   float64 `json:"soh"`                   // %   (e.g. 95.0)
	SelfDischargeRate     float64 `json:"selfDischargeRate"`     // %/month (e.g. 2.0)
	TemperatureAtDelivery float64 `json:"temperatureAtDelivery"` // °C  (e.g. 25.0)
}

// BatteryOrder is the asset stored on the batterychannel ledger.
type BatteryOrder struct {
	OrderID  string `json:"orderID"`
	Quantity int    `json:"quantity"`
	// Free-form spec string VoltRide sends when placing the order
	// e.g. {"vehicleModel":"VR-S1","batteryType":"LiPo"}
	Specifications string `json:"specifications"`
	Status         string `json:"status"`
	CreatedBy      string `json:"createdBy"`
	CreatedAt      string `json:"createdAt"`

	// --- Filled by BatteryOrg on FulfillOrder ---
	BatchID      string          `json:"batchID"`
	QCParams     BatteryQCParams `json:"qcParams"`
	MetadataHash string          `json:"metadataHash"` // SHA-256 hex of AWS file
	ZKProof      string          `json:"zkProof"`      // base64-encoded ZK proof
	FulfilledAt  string          `json:"fulfilledAt"`

	// --- Filled by VoltRide on Verify/Reject ---
	VerificationResult string `json:"verificationResult"` // "PASS" or "FAIL"
	RejectionReason    string `json:"rejectionReason"`
	VerifiedBy         string `json:"verifiedBy"`
	VerifiedAt         string `json:"verifiedAt"`
}

// ============================================================
// SmartContract
// ============================================================

type SmartContract struct {
	contractapi.Contract
}

type HistoryRecord struct {
    TxID      string      	`json:"txID"`
    Timestamp string      	`json:"timestamp"`
    IsDelete  bool        	`json:"isDelete"`
    Value     *BatteryOrder 	`json:"value,omitempty"`
}

// ============================================================
// Helpers
// ============================================================

func now() string {
	return time.Now().UTC().Format(time.RFC3339)
}

// isValidSHA256 checks the metadataHash is a 64-char hex string.
func isValidSHA256(hash string) bool {
	matched, _ := regexp.MatchString(`^[a-fA-F0-9]{64}$`, hash)
	return matched
}

// callerMSP returns the MSP ID of the transaction submitter.
func callerMSP(ctx contractapi.TransactionContextInterface) (string, error) {
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return "", fmt.Errorf("failed to get caller MSP ID: %v", err)
	}
	return mspID, nil
}

// getOrder fetches and deserialises an order from the ledger.
func getOrder(ctx contractapi.TransactionContextInterface, orderID string) (*BatteryOrder, error) {
	data, err := ctx.GetStub().GetState(orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to read order %s: %v", orderID, err)
	}
	if data == nil {
		return nil, fmt.Errorf("order %s does not exist", orderID)
	}
	var order BatteryOrder
	if err := json.Unmarshal(data, &order); err != nil {
		return nil, fmt.Errorf("failed to deserialise order: %v", err)
	}
	return &order, nil
}

// putOrder serialises and writes an order to the ledger.
func putOrder(ctx contractapi.TransactionContextInterface, order *BatteryOrder) error {
	data, err := json.Marshal(order)
	if err != nil {
		return fmt.Errorf("failed to serialise order: %v", err)
	}
	return ctx.GetStub().PutState(order.OrderID, data)
}

// validateQCParams checks that all 6 parameters are within
// physically plausible ranges for lithium-based EV batteries.
func validateQCParams(p BatteryQCParams) error {
	if p.NominalVoltage < 2.5 || p.NominalVoltage > 4.5 {
		return fmt.Errorf("nominalVoltage %.2f V out of range [2.5, 4.5]", p.NominalVoltage)
	}
	if p.InternalResistance < 0 || p.InternalResistance > 500 {
		return fmt.Errorf("internalResistance %.2f mΩ out of range [0, 500]", p.InternalResistance)
	}
	if p.Capacity < 1 || p.Capacity > 500 {
		return fmt.Errorf("capacity %.2f Ah out of range [1, 500]", p.Capacity)
	}
	if p.SOH < 0 || p.SOH > 100 {
		return fmt.Errorf("SOH %.2f %% out of range [0, 100]", p.SOH)
	}
	if p.SelfDischargeRate < 0 || p.SelfDischargeRate > 10 {
		return fmt.Errorf("selfDischargeRate %.2f %%/month out of range [0, 10]", p.SelfDischargeRate)
	}
	if p.TemperatureAtDelivery < -40 || p.TemperatureAtDelivery > 85 {
		return fmt.Errorf("temperatureAtDelivery %.2f °C out of range [-40, 85]", p.TemperatureAtDelivery)
	}
	return nil
}

// ============================================================
// Chaincode Functions
// ============================================================

// CreateOrder is called by VoltRide to raise a battery order.
func (s *SmartContract) CreateOrder(
	ctx contractapi.TransactionContextInterface,
	orderID string,
	quantity int,
	specifications string,
) error {
	msp, err := callerMSP(ctx)
	if err != nil {
		return err
	}
	if msp != VoltRideMSP {
		return fmt.Errorf("only VoltRide can create orders, caller is %s", msp)
	}
	if orderID == "" {
		return fmt.Errorf("orderID cannot be empty")
	}
	if quantity <= 0 {
		return fmt.Errorf("quantity must be greater than 0")
	}

	// Check duplicate
	existing, _ := ctx.GetStub().GetState(orderID)
	if existing != nil {
		return fmt.Errorf("order %s already exists", orderID)
	}

	order := &BatteryOrder{
		OrderID:        orderID,
		Quantity:       quantity,
		Specifications: specifications,
		Status:         StatusPending,
		CreatedBy:      msp,
		CreatedAt:      now(),
	}
	return putOrder(ctx, order)
}

// FulfillOrder is called by BatteryOrg to submit QC data,
// the metadata hash of the AWS file, and the ZK proof.
func (s *SmartContract) FulfillOrder(
	ctx contractapi.TransactionContextInterface,
	orderID string,
	batchID string,
	qcParamsJSON string,
	metadataHash string,
	zkProof string,
) error {
	msp, err := callerMSP(ctx)
	if err != nil {
		return err
	}
	if msp != BatteryMSP {
		return fmt.Errorf("only BatteryOrg can fulfill battery orders, caller is %s", msp)
	}

	order, err := getOrder(ctx, orderID)
	if err != nil {
		return err
	}
	if order.Status != StatusPending {
		return fmt.Errorf("order %s is not in PENDING state, current status: %s", orderID, order.Status)
	}
	if batchID == "" {
		return fmt.Errorf("batchID cannot be empty")
	}
	if !isValidSHA256(metadataHash) {
		return fmt.Errorf("metadataHash must be a valid 64-char SHA-256 hex string")
	}
	if zkProof == "" {
		return fmt.Errorf("zkProof cannot be empty")
	}

	// Parse and validate QC parameters
	var qcParams BatteryQCParams
	if err := json.Unmarshal([]byte(qcParamsJSON), &qcParams); err != nil {
		return fmt.Errorf("invalid qcParams JSON: %v", err)
	}
	if err := validateQCParams(qcParams); err != nil {
		return fmt.Errorf("QC parameter validation failed: %v", err)
	}

	order.BatchID = batchID
	order.QCParams = qcParams
	order.MetadataHash = metadataHash
	order.ZKProof = zkProof
	order.Status = StatusFulfilled
	order.FulfilledAt = now()

	return putOrder(ctx, order)
}

// VerifyAndAccept is called by VoltRide after running the ZK
// verifier off-chain and confirming the proof passes.
func (s *SmartContract) VerifyAndAccept(
	ctx contractapi.TransactionContextInterface,
	orderID string,
) error {
	msp, err := callerMSP(ctx)
	if err != nil {
		return err
	}
	if msp != VoltRideMSP {
		return fmt.Errorf("only VoltRide can verify orders, caller is %s", msp)
	}

	order, err := getOrder(ctx, orderID)
	if err != nil {
		return err
	}
	if order.Status != StatusFulfilled {
		return fmt.Errorf("order %s must be in FULFILLED state to verify, current: %s", orderID, order.Status)
	}

	order.Status = StatusAccepted
	order.VerificationResult = "PASS"
	order.VerifiedBy = msp
	order.VerifiedAt = now()

	return putOrder(ctx, order)
}

// RejectOrder is called by VoltRide when the ZK proof fails
// or the QC data does not meet requirements.
func (s *SmartContract) RejectOrder(
	ctx contractapi.TransactionContextInterface,
	orderID string,
	reason string,
) error {
	msp, err := callerMSP(ctx)
	if err != nil {
		return err
	}
	if msp != VoltRideMSP {
		return fmt.Errorf("only VoltRide can reject orders, caller is %s", msp)
	}
	if reason == "" {
		return fmt.Errorf("rejection reason cannot be empty")
	}

	order, err := getOrder(ctx, orderID)
	if err != nil {
		return err
	}
	if order.Status != StatusFulfilled {
		return fmt.Errorf("order %s must be in FULFILLED state to reject, current: %s", orderID, order.Status)
	}

	order.Status = StatusRejected
	order.VerificationResult = "FAIL"
	order.RejectionReason = reason
	order.VerifiedBy = msp
	order.VerifiedAt = now()

	return putOrder(ctx, order)
}

// CancelOrder is called by VoltRide to cancel a PENDING order.
func (s *SmartContract) CancelOrder(
	ctx contractapi.TransactionContextInterface,
	orderID string,
) error {
	msp, err := callerMSP(ctx)
	if err != nil {
		return err
	}
	if msp != VoltRideMSP {
		return fmt.Errorf("only VoltRide can cancel orders, caller is %s", msp)
	}

	order, err := getOrder(ctx, orderID)
	if err != nil {
		return err
	}
	if order.Status != StatusPending {
		return fmt.Errorf("only PENDING orders can be cancelled, current: %s", order.Status)
	}

	order.Status = StatusCancelled
	return putOrder(ctx, order)
}

// GetOrder returns a single order by ID. Any channel member can call this.
func (s *SmartContract) GetOrder(
	ctx contractapi.TransactionContextInterface,
	orderID string,
) (*BatteryOrder, error) {
	return getOrder(ctx, orderID)
}

// GetAllOrders returns all orders on this channel.
func (s *SmartContract) GetAllOrders(
	ctx contractapi.TransactionContextInterface,
) ([]*BatteryOrder, error) {
	iterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get all orders: %v", err)
	}
	defer iterator.Close()

	var orders []*BatteryOrder
	for iterator.HasNext() {
		result, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		var order BatteryOrder
		if err := json.Unmarshal(result.Value, &order); err != nil {
			return nil, err
		}
		orders = append(orders, &order)
	}
	return orders, nil
}

// GetOrderHistory returns the full audit trail for an order.
func (s *SmartContract) GetOrderHistory(
	ctx contractapi.TransactionContextInterface,
	orderID string,
) ([]HistoryRecord, error) {
	iterator, err := ctx.GetStub().GetHistoryForKey(orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to get history for %s: %v", orderID, err)
	}
	defer iterator.Close()

	var history []HistoryRecord
	for iterator.HasNext() {
		record, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		entry := HistoryRecord{
			TxID:      record.TxId,
			Timestamp: record.Timestamp.String(),
			IsDelete:  record.IsDelete,
		}
		if !record.IsDelete {
			var order BatteryOrder
			if err := json.Unmarshal(record.Value, &order); err == nil {
				entry.Value = &order
			}
		}
		history = append(history, entry)
	}
	return history, nil
}

// ============================================================
// Main
// ============================================================

func main() {
	cc, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		panic(fmt.Sprintf("Error creating battery chaincode: %v", err))
	}
	if err := cc.Start(); err != nil {
		panic(fmt.Sprintf("Error starting battery chaincode: %v", err))
	}
}
