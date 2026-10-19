{% snapshot stores_snapshot %}
-- stores are never deleted (closing a store sets closed_on), and the source has no updated_at
{{ config(unique_key='store_id', strategy='check', check_cols=['name', 'region'], hard_deletes='ignore') }}
select store_id, name, region from {{ source('shop', 'stores') }}
{% endsnapshot %}
