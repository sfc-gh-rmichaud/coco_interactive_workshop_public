-- One row per order line, flattened out of the nested items array.
--
-- A view, so it always reflects whatever stg_order_events currently holds. That
-- also means it inherits the deduplication rather than having to repeat it: if
-- the upstream model has duplicate event_ids, this doubles them silently, which
-- is why the `unique` test belongs upstream and not here.

SELECT
  e.event_id,
  e.occurred_at,
  e.customer_id,
  e.currency,
  e.channel,
  e.event_type,
  f.INDEX + 1                                            AS line_no,
  f.VALUE:sku::STRING                                    AS sku,
  f.VALUE:qty::NUMBER                                    AS qty,
  f.VALUE:unit_price::NUMBER(10,2)                       AS unit_price,
  f.VALUE:qty::NUMBER * f.VALUE:unit_price::NUMBER(10,2) AS line_amount
FROM {{ ref('stg_order_events') }} e,
     LATERAL FLATTEN(INPUT => e.items) f
