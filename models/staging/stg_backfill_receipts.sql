{{ 
  config(
    materialized='incremental',
    unique_key='tx_id',
    tags=['core', 'transactions'],
    cluster_by=['block_timestamp']
  )
}}

with

stg_receipts as (
  select 
    ingest_timestamp as ingested_at,
    try_parse_json(ingest_data) as ingest_data
  from {{ ref('stg_ant_ingest_receipts') }}
  where {{ incremental_load_filter("ingested_at") }}
),

raw_receipts as (
  select 
    ingest_data:subtype::string as tx_id, -- Eth tx hash
    ingest_data:data.result.transactionIndex as tx_index,
    ingest_data:data.result.from::string as native_from_address,
    ingest_data:data.result.to::string as native_to_address,
    js_onetohex(ingest_data:data.result.from::string) as from_address,
    js_onetohex(ingest_data:data.result.to::string) as to_address,
    ingest_data:data.result.blockNumber as block_id,
    ingest_data:data.result.blockHash::string as block_hash,
    ingest_data:data.result.contractAddress::string as contract_address,
    ingest_data:data.result.gasUsed as gas_used,
    ingest_data:data.result.cumulativeGasUsed as cumulative_gas_used,
    to_boolean(ingest_data:data.result.status::string) as status,
    array_size(ingest_data:data:result.logs) as logs_count,
    ingest_data:data.result.logsBloom::string as logs_bloom,    
    ingest_data:data.result.root::string as root,    
    ingest_data:data.result.shardID as shard_id, 
    ingest_data:data.result.transactionHash::string as native_tx_hash,
    ingested_at
  from stg_receipts as r
),

final as (
  select 
    b.block_timestamp as block_timestamp,
    r.*
  from raw_receipts as r
  left join {{ ref('stg_backfill_blocks') }} as b
    on b.block_id = r.block_id
)

select * from final
