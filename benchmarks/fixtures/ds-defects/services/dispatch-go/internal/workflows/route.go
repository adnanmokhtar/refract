package workflows

import (
	"time"

	"go.temporal.io/sdk/temporal"
	"go.temporal.io/sdk/workflow"
)

// RouteWorkflow drives one courier route from dispatch to the last stop.
func RouteWorkflow(ctx workflow.Context, routeID string, cutoff time.Time) error {
	ao := workflow.ActivityOptions{StartToCloseTimeout: 2 * time.Minute, RetryPolicy: &temporal.RetryPolicy{MaximumAttempts: 5}}
	ctx = workflow.WithActivityOptions(ctx, ao)

	var stops []string
	if err := workflow.ExecuteActivity(ctx, LoadStops, routeID).Get(ctx, &stops); err != nil {
		return err
	}
	for _, stop := range stops {
		if time.Now().After(cutoff) {
			return workflow.ExecuteActivity(ctx, ReturnToDepot, routeID).Get(ctx, nil)
		}
		if err := workflow.ExecuteActivity(ctx, DeliverStop, routeID, stop).Get(ctx, nil); err != nil {
			return err
		}
	}
	return nil
}
