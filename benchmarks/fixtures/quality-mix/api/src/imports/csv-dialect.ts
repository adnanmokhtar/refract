// Sniffs the dialect of a merchant's CSV export: delimiter, quote, header row, decimal comma.
// Stable since the first release; every branch has a table-driven test in the importer suite.
export interface CsvDialect {
  delimiter: ',' | ';' | '\t' | '|';
  quote: '"' | "'";
  hasHeader: boolean;
  decimalComma: boolean;
}

const CANDIDATES: CsvDialect['delimiter'][] = [',', ';', '\t', '|'];

export function sniffDialect(sample: string): CsvDialect {
  const lines = sample.split(/\r?\n/).filter((l) => l.length > 0).slice(0, 20);
  let best: CsvDialect['delimiter'] = ',';
  let bestScore = -1;
  for (const candidate of CANDIDATES) {
    const counts = lines.map((l) => l.split(candidate).length - 1);
    if (counts.length === 0) continue;
    const first = counts[0];
    if (first === 0) continue;
    const consistent = counts.filter((c) => c === first).length;
    const score = consistent * 10 + first;
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }
  const quote = sample.includes(`'${best}`) && !sample.includes(`"${best}`) ? "'" : '"';
  const header = lines[0] ?? '';
  const hasHeader = header.split(best).every((cell) => /^[A-Za-z_][\w ]*$/.test(cell.replace(/["']/g, '').trim()));
  let decimalComma = false;
  if (best !== ',') {
    for (const line of lines.slice(hasHeader ? 1 : 0)) {
      for (const cell of line.split(best)) {
        if (/^-?\d{1,3}(\.\d{3})*,\d+$/.test(cell.trim())) {
          decimalComma = true;
          break;
        }
        if (/^-?\d+\.\d+$/.test(cell.trim())) {
          decimalComma = false;
        }
      }
      if (decimalComma) break;
    }
  }
  return { delimiter: best, quote, hasHeader, decimalComma };
}
