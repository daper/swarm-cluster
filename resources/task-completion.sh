#!/bin/bash
# Run from the root of this repo (or change the path)

file=$(sed -n '/tasks/,$p' tasks.txt)
total=$(echo "$file" | tr -cd '+-' | wc -c)
incompleted=$(echo "$file" | tr -cd '-' | wc -c)
completed=$(echo "$file" | tr -cd '+' | wc -c)

per_completed=$(echo "scale=2; $completed/$total*100" | bc -l | sed -r 's/\.[0-9]+//')
per_incompleted=$(echo "scale=2; $incompleted/$total*100" | bc -l | sed -r 's/\.[0-9]+//')

cat <<EOT
Total:           $total
Incompleted:     $incompleted
Completed:       $completed
---------------------
You have done    ${per_completed}%
EOT
