# CERT

Protection des flux : conteneur qui gère automatiquement des certificats
HTTPS **gratuits** (Let's Encrypt) pour un ou plusieurs domaines, et bascule
le trafic HTTP en clair (port 80) vers HTTPS.

Cas d'usage initial : [www.printetreste.com](http://www.printetreste.com),
actuellement servi en HTTP (port 80) sans chiffrement.

## Comment ça marche

Le dépôt lance un unique conteneur **[Caddy](https://caddyserver.com/)**
qui joue le rôle de reverse proxy devant votre application :

- il écoute sur les ports **80** et **443** ;
- au démarrage (et automatiquement au renouvellement), il obtient un
  certificat TLS gratuit auprès de **Let's Encrypt** pour chaque domaine
  déclaré, sans intervention manuelle ;
- il redirige automatiquement tout le trafic HTTP vers HTTPS ;
- il relaie (`reverse_proxy`) les requêtes vers votre application, qui
  continue de tourner en clair en interne — elle n'a rien à changer ;
- il ajoute des en-têtes de sécurité de base (HSTS, anti-clickjacking, etc).

Pour ajouter d'autres domaines/sous-domaines (chacun avec son propre
certificat gratuit), il suffit de déposer un fichier dans
`caddy/sites/` — voir `caddy/sites/example.Caddyfile.example`.

## Prérequis

- Docker et Docker Compose installés sur le serveur qui héberge
  `printetreste.com`.
- Les enregistrements DNS (A / AAAA) de `printetreste.com` et
  `www.printetreste.com` doivent pointer vers ce serveur.
- Les ports **80** et **443** doivent être ouverts sur le pare-feu et
  **libres** (Let's Encrypt valide le domaine via le port 80/443 — si un
  autre service les occupe déjà, il faut le libérer ou l'arrêter avant de
  démarrer ce conteneur).
- Votre application actuelle (celle qui répond en HTTP) doit rester
  joignable en interne (autre port, autre conteneur, etc.) — ce n'est
  qu'en façade que le trafic devient HTTPS.

## Déploiement

1. Copier le fichier d'exemple et l'adapter :

   ```bash
   cp .env.example .env
   ```

   Renseigner dans `.env` :
   - `ACME_EMAIL` : votre email (alertes Let's Encrypt) ;
   - `DOMAIN` : `www.printetreste.com, printetreste.com` ;
   - `UPSTREAM` : où tourne l'application actuellement (`host:port`).

2. Si votre application tourne déjà dans Docker, connectez son conteneur
   au réseau `cert-net` créé par ce projet (ou adaptez `UPSTREAM` pour
   pointer vers son IP/nom sur le réseau qu'elle utilise déjà) :

   ```bash
   docker network connect cert-net <nom_du_conteneur_app>
   ```

   Si elle tourne hors Docker sur le même serveur, utilisez
   `UPSTREAM=host.docker.internal:80` (ou l'IP du serveur).

3. Démarrer le reverse proxy :

   ```bash
   make up
   # ou : docker compose up -d
   ```

4. Vérifier les logs (l'émission du certificat peut prendre quelques
   secondes à l'issue) :

   ```bash
   make logs
   ```

5. Tester : `https://www.printetreste.com` doit répondre avec un certificat
   valide, et `http://www.printetreste.com` doit rediriger vers HTTPS.

## Tester sans consommer le quota Let's Encrypt

Let's Encrypt limite le nombre de certificats délivrés par domaine et par
semaine. Pour valider votre configuration sans risquer d'atteindre cette
limite, décommentez la ligne `acme_ca` (environnement de test/staging)
dans `caddy/Caddyfile` avant un premier déploiement de test, puis
recommentez-la avant la mise en production réelle.

## Renouvellement des certificats

Aucune action requise : Caddy vérifie et renouvelle automatiquement les
certificats avant leur expiration (Let's Encrypt délivre des certificats
valables 90 jours, renouvelés généralement autour du 60ᵉ jour).

## Commandes utiles

```bash
make up        # démarre le conteneur
make down       # arrête le conteneur
make restart    # redémarre Caddy
make logs       # suit les logs en direct
make config     # valide la syntaxe du Caddyfile
make reload     # recharge la config sans coupure
```

## Structure du dépôt

```
.
├── docker-compose.yml       # définition du conteneur Caddy
├── .env.example              # variables à copier vers .env
├── Makefile                  # raccourcis de gestion
└── caddy/
    ├── Caddyfile              # config principale (domaine printetreste.com)
    └── sites/                 # un fichier par domaine additionnel
        └── example.Caddyfile.example
```
