# Golden files

Hand-computed expected outputs the finance team checks the code against offline:

- `ledger-2026-03-02.csv` — every journal line booked on 2026-03-02 (Europe/Berlin) for store `st_berlin_01`;
  each entry nets to zero per currency.
- `invoice-INV-2026-000184.xml` — the Peppol BIS 3.0 invoice for order `ord_7Q2K`, three lines with
  per-line rounded net amounts; it passes the KoSIT validator with the XRechnung configuration.
- `report-daily-sales-2026-03-02.csv` — the "Sales by day" figures for `st_berlin_01` in the store's zone,
  including an order paid at 23:40 local time (22:40 UTC) and one paid at 00:20 local time.
