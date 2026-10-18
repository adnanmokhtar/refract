import { formatDate, formatMoney } from '@acme/format';

type ReferenceCellProps = { reference: string };

export function ReferenceCell({ reference }: ReferenceCellProps) {
  return <td>{reference}</td>;
}

type TotalCellProps = { totalMinor: number };

export function TotalCell({ totalMinor }: TotalCellProps) {
  return <td>{formatMoney(totalMinor)}</td>;
}

type TaxCellProps = { taxMinor: number };

export function TaxCell({ taxMinor }: TaxCellProps) {
  return <td>{formatMoney(taxMinor)}</td>;
}

type ShippingCellProps = { shippingMinor: number };

export function ShippingCell({ shippingMinor }: ShippingCellProps) {
  return <td>{formatMoney(shippingMinor)}</td>;
}

type PlacedAtCellProps = { placedAt: string };

export function PlacedAtCell({ placedAt }: PlacedAtCellProps) {
  return <td>{formatDate(placedAt)}</td>;
}

type PaidAtCellProps = { paidAt: string };

export function PaidAtCell({ paidAt }: PaidAtCellProps) {
  return <td>{formatDate(paidAt)}</td>;
}

type ShippedAtCellProps = { shippedAt: string };

export function ShippedAtCell({ shippedAt }: ShippedAtCellProps) {
  return <td>{formatDate(shippedAt)}</td>;
}

type ItemCountCellProps = { itemCount: number };

export function ItemCountCell({ itemCount }: ItemCountCellProps) {
  return <td>{itemCount}</td>;
}

type CarrierCellProps = { carrier: string };

export function CarrierCell({ carrier }: CarrierCellProps) {
  return <td>{carrier}</td>;
}

type WarehouseCellProps = { warehouse: string };

export function WarehouseCell({ warehouse }: WarehouseCellProps) {
  return <td>{warehouse}</td>;
}

export const OrderCells = { ReferenceCell, TotalCell, TaxCell, ShippingCell, PlacedAtCell, PaidAtCell, ShippedAtCell, ItemCountCell, CarrierCell, WarehouseCell };
