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
    ingest_data:subtype::string as tx_id, -- Ethereum tx hash
    f.value:logIndex::string as event_index,
    ingest_data:data:result.to::string as native_contract_address,
    js_onetohex(ingest_data:data:result.to) as evm_contract_address,
    f.value:topics as topics,
    f.value:data::string as data,
    f.value:removed as event_removed,
    ingested_at
  from stg_parsed as b,
    lateral flatten(input => b.ingest_data, path => 'data.result.logs') as f
),

lookups as ( 
  select
    s.block_id,
    b.block_timestamp,
    s.tx_id,
    s.event_index,
    s.native_contract_address,
    s.evm_contract_address,
    null as contract_name, --c_lu.contract_name,
    null as event_name, --e_lu.event_name,
    null as event_inputs, -- this needs a mask or map stored in the event_lables table
    s.topics,
    s.data,
    s.event_removed
  from parsed2 as s 
  left join {{ ref('stg_backfill_blocks')}} as b
    on s.block_id = b.block_id
  --left join contract_labels as c_lu
    --on s.evm_contract_address = c_lu.evm_contract_address
  --left join event_labels as e_lu
    --on s.topics[0] = e_lu.topic0

),

final as (
  select
    concat_ws('-', tx_id, event_index) as log_id,
    *
  from lookups  
)

select * from final
