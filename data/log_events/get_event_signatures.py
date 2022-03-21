import requests
import json
import unicodedata
from csv import reader,writer
from datetime import datetime

next = 'https://www.4byte.directory/api/v1/event-signatures/?format=json&ordering=created_at&page=1'
header = {'Content-type': 'application/json'}
csv_file = open("/Users/admin/code/tonykau1/harmony_dbt/data/log_events/evm_event_signatures.csv", "w")
write_obj = writer(csv_file)
now = datetime.now()

csv_file.write("scrape_timestamp, id, created_at, name, params, text_signature, hex_signature\n")

while (next != None):
    r = requests.get(next, headers=header)
    j = json.loads(r.text)
    next = j['next']
    print(next)
    #print(j['previous'])
    for s in j['results']:
        nom = s['text_signature'].split("(")[0]
        vals = s['text_signature'].split("(")[1][:-1] 
        vals = "["+ vals + "]"
        csv_file.write('"' + str(now) + '",' + str(s['id']) + ',"' + s['created_at'] + '","' + nom + '","' + vals + '","' + s['text_signature'] + '",' + s['hex_signature'] + "\n")
    

    #print (r.text)
    #next = None

# while "next" value is not null
# query API
# append data to csv
# update "next" page value
# csv cols:  ingest_timestamp, id, created_at, text_signature, hex_signature
