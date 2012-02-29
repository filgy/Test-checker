#!/bin/bash
app="./runtests.sh"

clear

echo -e "[*] Starting application: $app $@\n"

eval '$app $@'

echo -e "\n[*] Return code is: $?"
