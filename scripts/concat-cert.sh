#!/bin/sh
# Hook de deploiement Certbot : execute apres chaque emission/renouvellement
# reussi. Concatene le certificat complet et la cle privee en un seul
# fichier .pem, format attendu par HAProxy pour `bind ... ssl crt`.
set -eu

mkdir -p /output
name=$(basename "$RENEWED_LINEAGE")
cat "$RENEWED_LINEAGE/fullchain.pem" "$RENEWED_LINEAGE/privkey.pem" > "/output/$name.pem"
chmod 600 "/output/$name.pem"

echo "Certificat combine genere : /output/$name.pem (a synchroniser vers le serveur HAProxy)"
