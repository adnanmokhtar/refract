"""Store locations as GeoJSON for the partner map embed (RFC 7946 FeatureCollection)."""
import json
from dataclasses import dataclass

from analytics.db import fetch_all


@dataclass(frozen=True)
class StoreRow:
    id: str
    name: str
    lat: float
    lng: float


def store_rows(tenant_id: str) -> list[StoreRow]:
    rows = fetch_all(
        "SELECT id, name, ST_Y(location) AS lat, ST_X(location) AS lng FROM stores WHERE tenant_id = %s",
        (tenant_id,),
    )
    return [StoreRow(str(r["id"]), r["name"], r["lat"], r["lng"]) for r in rows]


def store_features(tenant_id: str) -> dict:
    features = []
    for row in store_rows(tenant_id):
        features.append(
            {
                "type": "Feature",
                "geometry": {"type": "Point", "coordinates": [row.lat, row.lng]},
                "properties": {"id": row.id, "name": row.name},
            }
        )
    return {"type": "FeatureCollection", "features": features}


def export(tenant_id: str, path: str) -> None:
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(store_features(tenant_id), fh)
