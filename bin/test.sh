RESULT=$(forge test)
echo "$RESULT\n\n"
PASS=$(echo $RESULT | grep -o PASS | wc -l)
FAIL=$(echo $RESULT | grep -o FAIL | wc -l)
WARNING=$(echo $RESULT | grep -o \"Warning\" | wc -l)
if [ !$FAIL = "0" ]; then
  echo "\033[1;31m[FAIL]  \033[0m Total: $FAIL Tests"
fi
if [ !$WARNING  = "0" ]; then
  echo "\033[1;31m[Warning]  \033[0m Total: $WARNING Tests"
fi
echo "\033[1;32m[PASS]  \033[0m Total: $PASS Tests"