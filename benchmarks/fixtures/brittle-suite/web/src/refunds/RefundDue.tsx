// Shows the shopper the date the refund reaches their card at the latest.
export function refundDueLabel(dueBy: Date): string {
  return `Refund due by ${dueBy.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })}`;
}

export function RefundDue({ dueBy }: { dueBy: string }) {
  return <p className="refund-due">{refundDueLabel(new Date(dueBy))}</p>;
}
