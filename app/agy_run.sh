#!/bin/bash
# Lancia agy sulla UI dell'app; a quota esaurita passa al modello successivo. Esiti in app/agy_out/ (fuori git).
cd "$(dirname "$0")"
O=agy_out; mkdir -p $O
for m in ${AGY_CHAIN:-gemini-4-neon-xhigh gemini-4-neon-high gemini-4-argon-high}; do
  echo "$(date +%H:%M) avvio $m" >> $O/stato.txt
  agy -p "$(cat agy_brief.txt)" --model $m --sandbox \
    --output-format json --json-schema agy_schema.json \
    > $O/out_$m.txt 2> $O/err_$m.txt
  rc=$?
  echo "$(date +%H:%M) fine $m exit $rc" >> $O/stato.txt
  grep -qi "quota\|RESOURCE_EXHAUSTED" $O/out_$m.txt $O/err_$m.txt || break
done
