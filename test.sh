#!/bin/bash
app="./runtests.sh"

echo -e "[*] Starting application: $app $@\n"

eval "$app $@"

echo -e "\n[*] Return code is: $?"
