export function Orders() {
  const load = () => fetch('/api/orders');
  return <button onClick={load}>Load</button>;
}
