import _ from 'lodash';

export type PickLine = {
  id: string;
  aisle: string;
  name: string;
  quantity: number;
  imageUrl: string;
  looseWeight: boolean;
};

/** Groups a pick list by aisle, aisles in walking order. */
export function byAisle(lines: PickLine[]): Array<{ aisle: string; lines: PickLine[] }> {
  return _.sortBy(
    Object.entries(_.groupBy(lines, 'aisle')).map(([aisle, group]) => ({ aisle, lines: group })),
    (section) => section.aisle,
  );
}
