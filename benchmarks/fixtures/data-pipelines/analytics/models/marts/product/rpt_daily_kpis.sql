{{ config(materialized='view') }}

select country, orders, gross_cents
from {{ ref('int_kpi_base') }}
