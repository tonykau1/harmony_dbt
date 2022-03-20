{{ 
    config(
        materialized='incremental',
        unique_key='log_id',
        tags=['core', 'transactions'],
        cluster_by=['block_id']
        )
}}

with

stg_parsed as (
  select 
    ingest_timestamp as ingested_at,
    try_parse_json(ingest_data) as ingest_data
  from {{ ref('stg_ant_ingest_receipts') }}
  where {{ incremental_load_filter("ingested_at") }}
),

parsed2 as (
  select 
    to_numeric(ingest_data:data:result.blockNumber) as block_id,
    ingest_data:subtype as tx_id, -- Ethereum tx hash
    f.value:logIndex::string as event_index,
    ingest_data:data:result.to as native_contract_address,
    js_onetohex(ingest_data:data:result.to) as evm_contract_address,
    f.value:topics as topics,
    f.value:data::string as data,
    f.value:removed as event_removed,
    ingested_at
  from stg_parsed as b,
    lateral flatten(input => b.ingest_data, path => 'data.result.logs') as f
),

final as (
  select
    concat_ws('-', tx_id, event_index) as log_id,
    *
  from parsed2  
)

select * from final
