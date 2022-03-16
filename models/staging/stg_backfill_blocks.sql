{{ 
    config(
        materialized='incremental',
        unique_key='block_id',
        tags=['core'],
        cluster_by=['block_timestamp']
        )
}}

with

deduped_raw_blocks as (

    select 
        uuid_string() as record_id,
        to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.number,3))) as offset_id,
        to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.number,3))) as block_id,
        to_timestamp(to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.timestamp,3)))) as block_timestamp,
        'mainnet' as network,
        'harmony' as chain_id,
        array_size(parse_json(ingest_data):data:result:transactions) as tx_count,
        object_construct_keep_null(
        'blockHeight', parse_json(ingest_data):data:result.number,
        'blockTime', to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.timestamp,3))),
        'extraData', parse_json(ingest_data):data:result.extraData,
        'gasLimit', to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.gasLimit,3))),
        'gasUsed', to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.gasUsed,3))),
        'hash', parse_json(ingest_data):data:result.hash,
        'logs_bloom', parse_json(ingest_data):data:result.logsBloom,
        'miner', js_onetohex(parse_json(ingest_data):data:result.miner),
        'mix_hash', parse_json(ingest_data):data:result.mixHash,
        'nonce', '0x0000000000000000',
        'number', to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.number,3))),
        'parent_hash', parse_json(ingest_data):data:result.parentHash,
        'receipts_root', parse_json(ingest_data):data:result.receiptsRoot,
        'size', to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.size,3))),
        'state_root', parse_json(ingest_data):data:result.stateRoot,
        'timestamp', to_numeric(js_hextoint(substr(parse_json(ingest_data):data:result.timestamp,3))),
        'transactions', null,
        'transactions_root', (js_hextoint(substr(parse_json(ingest_data):data:result.transactionsRoot,3))),
        'tx_count', array_size(parse_json(ingest_data):data:result.transactions),
        'staking_tx_count', array_size(parse_json(ingest_data):data:result.stakingTransactions),
        'uncles', parse_json(ingest_data):data:result.uncles      
        ) as header,
        ingest_timestamp as ingested_at
    from {{ source("public","blocks") }}
    where {{ incremental_load_filter("ingested_at") }}
    qualify row_number() over (partition by block_id order by ingested_at desc) = 1

)

select * from deduped_raw_blocks
