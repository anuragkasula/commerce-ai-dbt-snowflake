-- TABLE: rebuilt in full every run. Fine for small dimensions.
select product_id, product_name, product_family, list_price_usd
from {{ ref('stg_commerce__products') }}
