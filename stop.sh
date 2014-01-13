pid=$(lsof -i:4567 -t)
kill -9 $pid
