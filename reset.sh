#!/bin/bash
echo "[*] Downloading test data"
rm -rf tree
bash -c "curl http://www.fit.vutbr.cz/study/courses/IOS/public/Lab/projekt1/tree.tar | tar xf -"  > /dev/null 2>&1
#mv tree/tests .
#rm -rf tree && mv tests tree

echo "[*] Successfully downloaded"
