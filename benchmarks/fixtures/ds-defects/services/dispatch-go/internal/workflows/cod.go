package workflows

import (
	"time"

	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
)

// CodCollectionWorkflow collects a cash-on-delivery fee at the door and remits it. If the delivery fails after the
// fee was captured, the fee is refunded.
func CodCollectionWorkflow(ctx workflow.Context, collectionID string) (err error) {
	ctx = workflow.WithActivityOptions(ctx, workflow.ActivityOptions{StartToCloseTimeout: time.Minute, RetryPolicy: &temporal.RetryPolicy{MaximumAttempts: 3}})

	if err = workflow.ExecuteActivity(ctx, CaptureCodFee, collectionID).Get(ctx, nil); err != nil {
		return err
	}
	defer func() {
		if err != nil {
			_ = workflow.ExecuteActivity(ctx, RefundCodFee, collectionID).Get(ctx, nil)
		}
	}()

	if err = workflow.ExecuteActivity(ctx, ConfirmDelivery, collectionID).Get(ctx, nil); err != nil {
		return err
	}
	return workflow.ExecuteActivity(ctx, RemitCod, collectionID).Get(ctx, nil)
}
