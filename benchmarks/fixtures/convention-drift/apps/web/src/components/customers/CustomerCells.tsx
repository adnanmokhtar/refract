import { formatDate, formatMoney } from '@acme/format';

type NameCellProps = { name: string };

export function NameCell({ name }: NameCellProps) {
  return <td>{name}</td>;
}

type EmailCellProps = { email: string };

export function EmailCell({ email }: EmailCellProps) {
  return <td>{email}</td>;
}

type PhoneCellProps = { phone: string };

export function PhoneCell({ phone }: PhoneCellProps) {
  return <td>{phone}</td>;
}

type CityCellProps = { city: string };

export function CityCell({ city }: CityCellProps) {
  return <td>{city}</td>;
}

type CountryCellProps = { country: string };

export function CountryCell({ country }: CountryCellProps) {
  return <td>{country}</td>;
}

type JoinedAtCellProps = { joinedAt: string };

export function JoinedAtCell({ joinedAt }: JoinedAtCellProps) {
  return <td>{formatDate(joinedAt)}</td>;
}

type LastOrderCellProps = { lastOrderAt: string };

export function LastOrderCell({ lastOrderAt }: LastOrderCellProps) {
  return <td>{formatDate(lastOrderAt)}</td>;
}

type LifetimeValueCellProps = { lifetimeMinor: number };

export function LifetimeValueCell({ lifetimeMinor }: LifetimeValueCellProps) {
  return <td>{formatMoney(lifetimeMinor)}</td>;
}

type OrderCountCellProps = { orderCount: number };

export function OrderCountCell({ orderCount }: OrderCountCellProps) {
  return <td>{orderCount}</td>;
}

export const CustomerCells = { NameCell, EmailCell, PhoneCell, CityCell, CountryCell, JoinedAtCell, LastOrderCell, LifetimeValueCell, OrderCountCell };
