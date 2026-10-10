INSERT INTO catalog_units (code, label) VALUES ('kg', 'Kilogram'), ('pc', 'Piece')
ON CONFLICT (code) DO NOTHING;
