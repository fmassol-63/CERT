# CERT

Protection des flux : conteneur qui obtient et renouvelle automatiquement
des certificats HTTPS **gratuits** (Let's Encrypt) pour un ou plusieurs
domaines, à charger dans votre **HAProxy** existant.

Cas d'usage initial : [www.printetreste.com](http://www.printetreste.com),
actuellement servi en HTTP (port 80) sans chiffrement, derrière une chaîne
**HAProxy → NGINX** qui ne fait pour l'instant que du HTTP clair.

## Architecture

```
Internet ──▶ HAProxy (80/443, autre dépôt/serveur) ──▶ NGINX ──▶ appli
                  │
                  │  /.well-known/acme-challenge/*
                  ▼
        conteneur acme-challenge (ce dépôt, port 8080)
                  ▲
                  │  écrit les fichiers de validation
        conteneur certbot (ce dépôt)
                  │
                  ▼
        ./output/<domaine>.pem  (cert + clé combinés)
                  │
                  ▼  à synchroniser manuellement/par script
        /etc/haproxy/certs/  sur le serveur HAProxy
```

Comme HAProxy occupe déjà les ports 80/443, ce dépôt **ne** tente **pas**
de les écouter lui-même. Il ne fait que :

1. **répondre aux challenges HTTP-01** de Let's Encrypt sur un port
   interne (`acme-challenge`, 8080 par défaut) — c'est HAProxy qui doit
   lui relayer les requêtes `/.well-known/acme-challenge/*` ;
2. **obtenir/renouvelir** les certificats via Certbot ;
3. **générer un `.pem` combiné** (certificat + clé privée) dans
   `./output/`, au format attendu par HAProxy (`bind ... ssl crt`).

C'est ensuite HAProxy — dans votre autre dépôt/serveur — qui **termine le
TLS** en 443 avec ce certificat, puis continue de relayer en HTTP clair
vers NGINX exactement comme aujourd'hui : **NGINX ne change pas**.

## Prérequis

- Docker et Docker Compose sur le serveur qui héberge ce dépôt (peut être
  le même serveur que HAProxy, ou un autre — seul le port
  `ACME_HTTP_PORT` doit être joignable depuis HAProxy).
- Les enregistrements DNS (A/AAAA) de `printetreste.com` et
  `www.printetreste.com` doivent pointer vers l'IP publique que HAProxy
  écoute en 80/443.
- Accès pour modifier la configuration HAProxy (dans votre autre dépôt).

## Déploiement

### 1. Ce dépôt : lancer l'émission des certificats

```bash
cp .env.example .env
# adapter ACME_EMAIL, DOMAINS, éventuellement ACME_HTTP_PORT
docker compose up -d
docker compose logs -f certbot
```

Laissez `STAGING=true` pour un premier essai (évite d'épuiser le quota
Let's Encrypt en cas d'erreur de config), puis repassez à `false` et
relancez (`docker compose restart certbot`) une fois la chaîne validée.

### 2. Votre dépôt HAProxy : brancher le challenge et le certificat

Copiez/adaptez `haproxy/snippet.cfg.example` (fourni ici à titre de
documentation, à reporter dans la vraie config HAProxy) :

- une ACL sur le frontend HTTP (80) qui relaie
  `/.well-known/acme-challenge/*` vers le conteneur `acme-challenge` de
  ce dépôt (`<IP_DU_SERVEUR_CERT>:8080`) ;
- le reste du trafic HTTP redirigé en HTTPS (`redirect scheme https`) ;
- un frontend HTTPS (`bind *:443 ssl crt /etc/haproxy/certs/`) qui
  charge le(s) `.pem` combiné(s) et continue de relayer vers le backend
  NGINX existant, inchangé.

Tant que le certificat n'a jamais été émis, la ligne `bind *:443 ssl crt`
n'a rien à charger : commencez par l'étape 1 pour obtenir un premier
`.pem` dans `./output/`.

### 3. Synchroniser le certificat vers HAProxy

Le `.pem` combiné est régénéré dans `./output/` à chaque émission ou
renouvellement (Certbot boucle automatiquement toutes les 12h en interne
et renouvelle ~30 jours avant expiration). Il faut le pousser vers
`/etc/haproxy/certs/` sur le serveur HAProxy et recharger HAProxy.

Adaptez `scripts/sync-to-haproxy.sh.example` (hôte, utilisateur SSH,
chemin) puis automatisez son exécution (cron, ou ajoutez-le comme second
`--deploy-hook` Certbot) :

```bash
cp scripts/sync-to-haproxy.sh.example scripts/sync-to-haproxy.sh
chmod +x scripts/sync-to-haproxy.sh
# tester manuellement, puis planifier (ex: cron toutes les nuits)
```

## Tester sans consommer le quota Let's Encrypt

`STAGING=true` dans `.env` utilise l'environnement de test de Let's
Encrypt (certificat non reconnu par les navigateurs, mais permet de
valider tout le circuit HAProxy → acme-challenge → Certbot sans risquer
d'atteindre la limite de certificats par domaine/semaine).

## Commandes utiles

```bash
docker compose up -d              # démarre acme-challenge + certbot
docker compose logs -f certbot    # suit l'émission/le renouvellement
docker compose down               # arrête les conteneurs
```

## Structure du dépôt

```
.
├── docker-compose.yml               # conteneurs acme-challenge + certbot
├── .env.example                      # variables à copier vers .env
├── scripts/
│   ├── entrypoint.sh                  # boucle certbot certonly + renew
│   ├── concat-cert.sh                 # deploy-hook : génère le .pem combiné
│   └── sync-to-haproxy.sh.example     # exemple de synchro vers HAProxy
├── haproxy/
│   └── snippet.cfg.example            # extraits à reporter dans votre config HAProxy
└── output/                            # .pem générés (ignorés par git)
```
