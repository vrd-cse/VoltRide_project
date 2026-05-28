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
	ChassisMSP  = "ChassisMSP"
)

// ============================================================
// Asset Definitions
// ============================================================

// ChassisQCParams holds the 6 QC parameters measured by ChassisOrg.
// These are also the public inputs to the ZK proof circuit.
type ChassisQCParams struct {
	WeldQuality          float64 `json:"weldQuality"`          // score 0-100
	FrameWeight          float64 `json:"frameWeight"`          // kg   (e.g. 12.5)
	DimensionalAccuracy  float64 `json:"dimensionalAccuracy"`  // mm deviation (e.g. 0.2)
	MaterialGrade        string  `json:"materialGrade"`        // e.g. "S235", "6061-T6"
	SurfaceDefectCount   int     `json:"surfaceDefectCount"`   // count (e.g. 0)
	LoadBearingCapacity  float64 `json:"loadBearingCapacity"`  // kg   (e.g. 150.0)
}

// ChassisOrder is the asset stored on the chassischannel ledger.
type ChassisOrder struct {
	OrderID        string `json:"orderID"`
	Quantity       int    `json:"quantity"`
	Specifications string `json:"specifications"`
	Status         string `json:"status"`
	CreatedBy      string `json:"createdBy"`
	CreatedAt      string `json:"createdAt"`

	// --- Filled by ChassisOrg on FulfillOrder ---
	BatchID      string          `json:"batchID"`
	QCParams     ChassisQCParams `json:"qcParams"`
	MetadataHash string          `json:"metadataHash"` // SHA-256 hex of AWS file
	ZKProof      string          `json:"zkProof"`      // base64-encoded ZK proof
	FulfilledAt  string          `json:"fulfilledAt"`

	// --- Filled by VoltRide on Verify/Reject ---
	VerificationResult string `json:"verificationResult"`
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
    TxID      string        `json:"txID"`
    Timestamp string        `json:"timestamp"`
    IsDelete  bool          `json:"isDelete"`
    Value     *ChassisOrder `json:"value,omitempty"`
}


// ============================================================
// Helpers
// ============================================================

func now() string {
	return time.Now().UTC().Format(time.RFC3339)
}

func isValidSHA256(hash string) bool {
	matched, _ := regexp.MatchString(`^[a-fA-F0-9]{64}$`, hash)
	return matched
}

func callerMSP(ctx contractapi.TransactionContextInterface) (string, error) {
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return "", fmt.Errorf("failed to get caller MSP ID: %v", err)
	}
	return mspID, nil
}

func getOrder(ctx contractapi.TransactionContextInterface, orderID string) (*ChassisOrder, error) {
	data, err := ctx.GetStub().GetState(orderID)
	if err != nil {
		return nil, fmt.Errorf("failed to read order %s: %v", orderID, err)
	}
	if data == nil {
		return nil, fmt.Errorf("order %s does not exist", orderID)
	}
	var order ChassisOrder
	if err := json.Unmarshal(data, &order); err != nil {
		return nil, fmt.Errorf("failed to deserialise order: %v", err)
	}
	return &order, nil
}

func putOrder(ctx contractapi.TransactionContextInterface, order *ChassisOrder) error {
	data, err := json.Marshal(order)
	if err != nil {
		return fmt.Errorf("failed to serialise order: %v", err)
	}
	return ctx.GetStub().PutState(order.OrderID, data)
}

// validateQCParams checks all 6 parameters are within
// physically plausible ranges for EV scooter chassis.
func validateQCParams(p ChassisQCParams) error {
	if p.WeldQuality < 0 || p.WeldQuality > 100 {
		return fmt.Errorf("weldQuality %.2f out of range [0, 100]", p.WeldQuality)
	}
	if p.FrameWeight < 1 || p.FrameWeight > 100 {
		return fmt.Errorf("frameWeight %.2f kg out of range [1, 100]", p.FrameWeight)
	}
	if p.DimensionalAccuracy < 0 || p.DimensionalAccuracy > 50 {
		return fmt.Errorf("dimensionalAccuracy %.4f mm out of range [0, 50]", p.DimensionalAccuracy)
	}
	if p.MaterialGrade == "" {
		return fmt.Errorf("materialGrade cannot be empty")
	}
	if p.SurfaceDefectCount < 0 {
		return fmt.Errorf("surfaceDefectCount %d cannot be negative", p.SurfaceDefectCount)
	}
	if p.LoadBearingCapacity < 1 || p.LoadBearingCapacity > 5000 {
		return fmt.Errorf("loadBearingCapacity %.2f kg out of range [1, 5000]", p.LoadBearingCapacity)
	}
	return nil
}

// ============================================================
// Chaincode Functions
// ============================================================

// CreateOrder is called by VoltRide to raise a chassis order.
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

	existing, _ := ctx.GetStub().GetState(orderID)
	if existing != nil {
		return fmt.Errorf("order %s already exists", orderID)
	}

	order := &ChassisOrder{
		OrderID:        orderID,
		Quantity:       quantity,
		Specifications: specifications,
		Status:         StatusPending,
		CreatedBy:      msp,
		CreatedAt:      now(),
	}
	return putOrder(ctx, order)
}

// FulfillOrder is called by ChassisOrg to submit QC data,
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
	if msp != ChassisMSP {
		return fmt.Errorf("only ChassisOrg can fulfill chassis orders, caller is %s", msp)
	}

	order, err := getOrder(ctx, orderID)
	if err != nil {
		return err
	}
	if order.Status != StatusPending {
		return fmt.Errorf("order %s is not PENDING, current status: %s", orderID, order.Status)
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

	var qcParams ChassisQCParams
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

// VerifyAndAccept is called by VoltRide after off-chain ZK verification passes.
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
		return fmt.Errorf("order %s must be FULFILLED to verify, current: %s", orderID, order.Status)
	}

	order.Status = StatusAccepted
	order.VerificationResult = "PASS"
	order.VerifiedBy = msp
	order.VerifiedAt = now()

	return putOrder(ctx, order)
}

// RejectOrder is called by VoltRide when verification fails.
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
		return fmt.Errorf("order %s must be FULFILLED to reject, current: %s", orderID, order.Status)
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

// GetOrder returns a single order. Any channel member can call this.
func (s *SmartContract) GetOrder(
	ctx contractapi.TransactionContextInterface,
	orderID string,
) (*ChassisOrder, error) {
	return getOrder(ctx, orderID)
}

// GetAllOrders returns all orders on this channel.
func (s *SmartContract) GetAllOrders(
	ctx contractapi.TransactionContextInterface,
) ([]*ChassisOrder, error) {
	iterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, fmt.Errorf("failed to get all orders: %v", err)
	}
	defer iterator.Close()

	var orders []*ChassisOrder
	for iterator.HasNext() {
		result, err := iterator.Next()
		if err != nil {
			return nil, err
		}
		var order ChassisOrder
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
			var order ChassisOrder
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
		panic(fmt.Sprintf("Error creating chassis chaincode: %v", err))
	}
	if err := cc.Start(); err != nil {
		panic(fmt.Sprintf("Error starting chassis chaincode: %v", err))
	}
}
