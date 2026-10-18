import { t } from '@acme/i18n';
import { IconButton } from '../icon-button/IconButton';
import { TrashIcon } from '../icons';

export type Column<T> = { key: keyof T & string; header: string };

export type DataTableProps<T> = {
  rows: T[];
  columns: Column<T>[];
  /** Row-delete affordance. Defaults to true: a read-only page passes `canDelete={false}`. */
  canDelete?: boolean;
  onDelete?: (row: T) => void;
};

export function DataTable<T extends { id: string }>({ rows, columns, canDelete = true, onDelete }: DataTableProps<T>) {
  return (
    <table>
      <thead>
        <tr>
          {columns.map((c) => (
            <th key={c.key}>{c.header}</th>
          ))}
          {canDelete ? <th /> : null}
        </tr>
      </thead>
      <tbody>
        {rows.map((row) => (
          <tr key={row.id}>
            {columns.map((c) => (
              <td key={c.key}>{String(row[c.key])}</td>
            ))}
            {canDelete ? (
              <td>
                <IconButton icon={TrashIcon} label={t('common.delete')} onClick={() => onDelete?.(row)} />
              </td>
            ) : null}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
