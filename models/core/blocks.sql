{{
    config(
        materialized='incremental',
        unique_key='block_id',
        tags=['core'],
        cluster_by=['block_timestamp']
    )
}}

with base_blocks as (

    select * from {{ ref("stg_blocks") }}
    where {{ incremental_load_filter("block_timestamp") }}
),

backfill_blocks as (
    select * from {{ ref('stg_backfill_blocks')}}
    where {{ incremental_load_filter("block_timestamp") }}
),

unioned_blocks as ( 
    select * from base_blocks

    union all
    
    select 
        null as record_id,
        * 
    from backfill_blocks
)

final as (

    select

        block_id,
        block_timestamp,
        header:hash::string as block_hash,
        header:parent_hash::string as block_parent_hash,
        header:gas_limit as gas_limit,
        header:gas_used as gas_used,
        header:miner::string as miner,
        header:nonce::string as nonce,
        header:size as size,
        tx_count,
        header:state_root::string as state_root,
        header:receipts_root::string as receipts_root

    from unioned_blocks 
    qualify row_number() over (partition by block_id order by ingested_at desc) = 1
)

select * from final
