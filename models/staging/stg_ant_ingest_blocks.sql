{{ 
    config(
        materialized='incremental',
        unique_key='ingest_timestamp',
        incremental_strategy = 'delete+insert',
        tags=['core','ingest'],
        cluster_by=['ingest_timestamp']
        )
}}

with
source_table as (

    select
        ingest_timestamp,
        ingest_data
    from {{ source("ingest","blocks") }}
    where {{ incremental_load_filter("ingested_at") }}

)

select * from source_table
