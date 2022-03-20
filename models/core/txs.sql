{{ 
     config(
         materialized = 'incremental',
         unique_key = 'tx_hash',
         tags = ['core'],
         cluster_by = ['block_timestamp']
     ) 
}}

with base_txs as (

    select * from {{ ref("stg_txs") }}
    where {{ incremental_load_filter("block_timestamp") }}
),

base2 as (
    select
        block_timestamp,
        tx:nonce::string as nonce,
        tx_block_index as index,
        tx:bech32_from::string as native_from_address,
        tx:bech32_to::string as native_to_address,
        tx:from::string as from_address,
        tx:to::string as to_address,
        tx:value as value,
        tx:block_number as block_number,
        tx:block_hash::string as block_hash,
        tx:gas_price as gas_price,
        tx:gas as gas,
        tx_id as tx_hash,
        tx:input::string as data,
        tx:receipt:status::string = '0x1'  as status
    from base_txs
),

backfill as ( 
    select 
        block_timestamp,
        nonce,
        tx_index as index,
        native_from_address,
        native_to_address,
        from_address,
        to_address,
        value,
        block_id as block_number,
        b.header:hash::string as block_hash,
        gas_price,
        gas_used as gas,
        tx_id as tx_hash,
        input as data,
        status
    from {{ ref('stg_backfill_txs') }} as t
    left join {{ ref('stg_backfill_blocks')}} as b
        on t.block_id = b.block_id
),

unioned_txs as ( 
    select * from base2

    union all
    
    select * from backfill
),

final as ( 
    select * from unioned_txs 
    qualify row_number() over (partition by tx_hash) = 1
)

select * from final

