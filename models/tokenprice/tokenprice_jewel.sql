{{ 
    config(
        materialized='incremental',
        unique_key = 'timestamp',
        incremental_strategy = 'delete+insert',
        tags=['tokenprice'],
        cluster_by=['timestamp']
    )
}}

with

raw_logs as (
    select 
        block_timestamp,
        java_hextoint(substr(data,3+64*0,64)) as amount0In,
        java_hextoint(substr(data,3+64*1,64)) as amount1In,
        java_hextoint(substr(data,3+64*2,64)) as amount0Out,
        java_hextoint(substr(data,3+64*3,64)) as amount1Out
    from {{ ref('logs') }}
    where topics[0] = '0xd78ad95fa46c994b6551d0da85fc275fe613ce37657fb8d5e3d130840159d822' -- Swap
        and evm_contract_address = '0xa1221a5bbea699f507cc00bdedea05b5d2e32eba' -- JEWEL / 1USDC Pool
        and {{ incremental_last_x_days("block_timestamp", 3) }}
),

daily_trades as (
    select 
        date_trunc('day', block_timestamp) as day_date,
        sum(amount0In) as sum0in,
        sum(amount1In) as sum1in,
        sum(amount0Out) as sum0out,
        sum(amount1Out) as sum1out
    from raw_logs
    group by 1
),

daily_trades_prices as (
    select
        -- column is set to timestamp for future purposes (once we get matt's hourly data)
        day_date as timestamp,
        /* 
            Calculation is done by
            1. ((bigger token deom) / (smaller token denom)) [because these are integers and not floats]
            2. converted to correct decimal place (e.g [multiplied] * pow(10,-8))
            3. converted to USD Price (using 1/result && [multiplied] * jewel.price)
        */
        1 / ( (sum0in + sum0out) / (sum1in + sum1out) ) * pow(10,12) as price
    from daily_trades d
),

combine as (
    select 
        *
    from daily_trades_prices
),

final as (
    select 
        timestamp,
        avg(price) as price
    from combine
    group by 1
)

select * from final
