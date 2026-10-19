-- Product reviews (v1). Written by hand rather than as a MikroORM migration because the
-- review service team owns this table and its rating trigger.
-- Applied by deploy/k8s/sql-migrate-job.yaml with psql -v ON_ERROR_STOP=1; each statement
-- runs in its own transaction (there is no BEGIN in this file).

create table review (
  id           uuid        not null default gen_random_uuid() primary key,
  product_id   uuid        not null references product (id) on delete cascade,
  author_id    uuid        not null references "user" (id),
  rating       smallint    not null check (rating between 1 and 5),
  body         text        not null,
  photo_url    varchar(300),
  created_at   timestamptz not null default now()
);

create index review_author_id_idx on review (author_id);

-- Denormalised rating on product, for the listing cards.
alter table product add column rating_avg numeric(3, 2);
alter table product add column rating_count integer not null default 0;

-- "Latest reviews" rail on the storefront home page.
create index review_created_at_idx on review (created_at);

create or replace function review_rating_refresh() returns trigger
language plpgsql as $$
begin
  update product p
     set rating_avg   = s.avg,
         rating_count = s.cnt
    from (select avg(rating)::numeric(3, 2) as avg, count(*) as cnt
            from review
           where product_id = coalesce(new.product_id, old.product_id)) s
   where p.id = coalesce(new.product_id, old.product_id);
  return null;
end $$;

create trigger review_rating_refresh
after insert or update or delete on review
for each row execute function review_rating_refresh();

-- Buyer order history (GET /me/orders) filters by customer and has been sequentially
-- scanning order since the guest-checkout launch. Index it.
create index order_customer_id_idx on "order" (customer_id);
