package workflows

import "context"

func LoadStops(ctx context.Context, routeID string) ([]string, error)   { return nil, nil }
func DeliverStop(ctx context.Context, routeID, stop string) error        { return nil }
func ReturnToDepot(ctx context.Context, routeID string) error            { return nil }
func CaptureCodFee(ctx context.Context, collectionID string) error       { return nil }
func ConfirmDelivery(ctx context.Context, collectionID string) error     { return nil }
func RemitCod(ctx context.Context, collectionID string) error            { return nil }
func RefundCodFee(ctx context.Context, collectionID string) error        { return nil }
