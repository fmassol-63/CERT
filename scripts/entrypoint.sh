#!/bin/sh
# Emet le(s) certificat(s) Let's Encrypt (methode webroot) puis boucle sur
# `certbot renew` toutes les 12h. A chaque emission/renouvellement reussi,
# le hook concat-cert.sh (monte dans renewal-hooks/deploy) genere un .pem
# combine dans /output, pret a etre synchronise vers HAProxy.
set -eu

DOMAIN_ARGS=""
OLD_IFS="$IFS"
IFS=','
for d in $DOMAINS; do
	DOMAIN_ARGS="$DOMAIN_ARGS -d $d"
done
IFS="$OLD_IFS"

STAGING_ARGS=""
if [ "${STAGING:-false}" = "true" ]; then
	STAGING_ARGS="--staging"
fi

# shellcheck disable=SC2086
certbot certonly \
	--non-interactive --agree-tos \
	--webroot -w /var/www/acme-challenge \
	--email "$ACME_EMAIL" \
	$DOMAIN_ARGS $STAGING_ARGS \
	--deploy-hook /etc/letsencrypt/renewal-hooks/deploy/concat-cert.sh \
	|| echo "Emission initiale ignoree (certificat deja present ?), on passe au renouvellement periodique."

trap exit TERM
while :; do
	certbot renew --webroot -w /var/www/acme-challenge \
		--deploy-hook /etc/letsencrypt/renewal-hooks/deploy/concat-cert.sh
	sleep 12h &
	wait $!
done
