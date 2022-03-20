{{ 
  config(
    materialized='incremental',
    unique_key='tx_id',
    tags=['core', 'transactions'],
    cluster_by=['block_timestamp']
  )
}}

with

stg_parsed as (
  select 
    ingest_timestamp as ingested_at,
    try_parse_json(ingest_data) as ingest_data
  from {{ ref('stg_ant_ingest_blocks') }}
  where {{ incremental_load_filter("ingested_at") }}
),

raw_txs as (
  select 
    f.value:ethHash::string as tx_id, -- Eth tx hash
    to_numeric(js_hextoint(substr(f.value:transactionIndex::string,3))) as tx_index,
    to_numeric(js_hextoint(substr(ingest_data:data:result.number,3))) as block_id,
    to_timestamp(to_numeric(js_hextoint(substr(ingest_data:data:result.timestamp,3)))) as block_timestamp,
    f.value:from::string as native_from_address,
    f.value:to::string as native_to_address,
    js_onetohex(f.value:from::string) as from_address,
    js_onetohex(f.value:to::string) as to_address,
    to_numeric(js_hextoint(substr(f.value:gas::string,3))) as gas_used,
    to_numeric(js_hextoint(substr(f.value:gasPrice::string,3))) as gas_price,
    f.value:hash::string as native_tx_hash,
    f.value:input as input,
    f.value:nonce as nonce,
    f.value:r as r,
    f.value:s as s,
    f.value:v as v,
    to_numeric(js_hextoint(substr(f.value:value::string,3))) as value,
    ingested_at
  from stg_parsed as b,
    lateral flatten(input => b.ingest_data, path => 'data.result.transactions') as f
),

final as (  -- add lookup for status from receipts ingest
  select 
    t.*,
    r.status
  from raw_txs as t
  left join {{ref ('stg_backfill_receipts')}} as r
    on t.tx_id = r.tx_id
)

select * from final
