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

deduped_raw_txs as (
    select 
    f.value:hash::string as tx_id,
    to_numeric(js_hextoint(substr(f.value:transactionIndex::string,3))) as tx_block_index,
    to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.number,3))) as block_id,
    to_timestamp(to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.timestamp,3)))) as block_timestamp,
    object_construct_keep_null(
      'bech32_from', f.value:from,
      'bech32_to', f.value:to,
      'block_hash', f.value:blockHash,
      'block_number', to_numeric(js_hextoint(substr(f.value:blockNumber::string,3))),
      'from', js_onetohex(f.value:from::string),
      'gas', to_numeric(js_hextoint(substr(f.value:gas::string,3))),
      'gas_price', to_numeric(js_hextoint(substr(f.value:gasPrice::string,3))),
      'hash', f.value:hash,
      'input', f.value:input,
      'nonce', f.value:nonce,
      'r', f.value:r,
      's', f.value:s,
      'to', js_onetohex(f.value:to::string),
      'transactionIndex', to_numeric(js_hextoint(substr(f.value:transactionIndex::string,3))),
      'v', f.value:v,
      'value', to_numeric(js_hextoint(substr(f.value:value::string,3)))
    ) as tx,
    ingested_at
 from stg_parsed as b,
   lateral flatten(input => b.ingest_data, path => 'data.result.transactions') as f
  --where 
    --qualify row_number() over (partition by block_id order by ingested_at desc) = 1
)

select * from deduped_raw_txs
