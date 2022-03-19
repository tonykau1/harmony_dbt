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
    from {{ source("ingest","receipts") }}
    where {{ incremental_load_filter("ingest_timestamp") }}
        qualify row_number() over (partition by ingest_data order by ingest_timestamp desc) = 1
)

select * from source_table
