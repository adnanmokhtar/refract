import styled from 'styled-components';

// Frozen by ADR-0009 until 2027-03-31; deleted when the reports rewrite ships.
const Table = styled.table`
  width: 100%;
  border-collapse: collapse;
  font-size: 13px;
`;

const HeaderCell = styled.th`
  padding: 8px 12px;
  color: #667085;
  text-align: left;
`;

export function ReportTable({ rows }: { rows: Array<{ id: string; label: string; value: string }> }) {
  return (
    <Table>
      <thead>
        <tr>
          <HeaderCell>Metric</HeaderCell>
          <HeaderCell>Value</HeaderCell>
        </tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <tr key={r.id}>
            <td>{r.label}</td>
            <td>{r.value}</td>
          </tr>
        ))}
      </tbody>
    </Table>
  );
}
