export interface LineDraft {
  sku: string;
  quantity: number;
  unit_price: number;
}

export function LinesEditor({ value, onChange }: { value: LineDraft[]; onChange: (v: LineDraft[]) => void }) {
  return (
    <table>
      <tbody>
        {value.map((line, i) => (
          <tr key={i}>
            <td>
              <input value={line.sku} onChange={(e) => onChange(value.map((l, j) => (j === i ? { ...l, sku: e.target.value } : l)))} />
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
