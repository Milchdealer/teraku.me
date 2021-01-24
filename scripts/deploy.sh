#!/usr/bin/env bash
USER=teraku
HOST=teraku.de
DIR=www/teraku.de/

echo "Deploy hugo site"
cd .. && hugo && rsync -avz --delete public/ ${USER}@${HOST}:~/${DIR}

echo "Done."
