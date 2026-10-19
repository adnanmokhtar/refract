-- the support replica in Snowflake masks contact data by tag
create or replace masking policy pii.mask_contact as (val string) returns string ->
  case when current_role() in ('SUPPORT_ADMIN') then val else '***' end;

alter tag pii.contact set masking policy pii.mask_contact;

alter table support.customers modify column email set tag pii.contact = 'email';
alter table support.customers modify column phone_number set tag pii.contact = 'phone';
