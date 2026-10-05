package ledger

import (
	"context"
	"testing"

	"github.com/stretchr/testify/mock"
)

type payoutsMock struct{ mock.Mock }

func (m *payoutsMock) Send(ctx context.Context, s Settlement) error {
	return m.Called(ctx, s).Error(0)
}

func TestSettleSendsTheNetPayout(t *testing.T) {
	p := &payoutsMock{}
	p.On("Send", mock.Anything, mock.Anything).Return(nil)

	_, _ = Settle(context.Background(), p, "m_1", 100_000, 12_000, 150)

	p.AssertExpectations(t)
}
