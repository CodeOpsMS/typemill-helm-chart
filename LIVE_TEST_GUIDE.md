# Typemill Live-Test auf eurem RKE2-Cluster

## Cluster-Info (Stand 16.03.2026)
- **Cluster:** 7 Nodes (3 CP + 4 Worker), RKE2 v1.34.3
- **StorageClass:** `longhorn` (default)
- **IngressClass:** `nginx`
- **cert-manager:** vorhanden

---

## Schritt 1: Namespace erstellen

```bash
kubectl create namespace typemill
```

## Schritt 2: Helm Install (ohne Ingress, nur zum Testen)

```bash
cd /Users/ms/Documents/projects/laemmerzahl/typemill-helm-chart

helm install typemill charts/typemill \
  --namespace typemill \
  --set persistence.enabled=true \
  --set persistence.storageClass=longhorn \
  --set persistence.size=2Gi \
  --set typemill.timezone="Europe/Berlin"
```

## Schritt 3: Deployment prüfen

```bash
# Pod-Status prüfen (sollte nach ~30s Running sein)
kubectl -n typemill get pods -w

# Events prüfen falls der Pod nicht startet
kubectl -n typemill describe pod -l app.kubernetes.io/name=typemill

# PVC prüfen
kubectl -n typemill get pvc

# Logs prüfen
kubectl -n typemill logs -l app.kubernetes.io/name=typemill -f
```

## Schritt 4: Port-Forward und Erster Zugriff

```bash
kubectl -n typemill port-forward svc/typemill 8080:80
```

Dann im Browser öffnen:
- **http://localhost:8080** → sollte zu `/tm/setup` weiterleiten
- **http://localhost:8080/tm/setup** → Setup-Wizard, Admin-User anlegen
- **http://localhost:8080/tm/login** → Login-Seite (Health-Check-Endpunkt)

## Schritt 5: Funktionstest nach Setup

Nach dem Setup-Wizard prüfen:
- [ ] Setup-Wizard durchlaufen (Admin-User erstellen)
- [ ] Login funktioniert unter `/tm/login`
- [ ] Dashboard erreichbar unter `/tm/content`
- [ ] Neue Seite erstellen (Markdown-Editor)
- [ ] Media-Upload testen (Bild hochladen)
- [ ] Frontend anzeigen (Startseite)

## Schritt 6: Persistenz-Test (Pod killen & prüfen)

```bash
# Pod löschen (Deployment erstellt automatisch einen neuen)
kubectl -n typemill delete pod -l app.kubernetes.io/name=typemill

# Warten bis neuer Pod läuft
kubectl -n typemill get pods -w

# Port-Forward erneut starten
kubectl -n typemill port-forward svc/typemill 8080:80
```

Dann prüfen:
- [ ] Login funktioniert noch (Settings persistiert)
- [ ] Erstellte Seiten sind noch da (Content persistiert)
- [ ] Hochgeladene Medien noch vorhanden (Media persistiert)

## Schritt 7 (Optional): Mit Ingress deployen

Falls ihr einen DNS-Eintrag habt (z.B. `typemill.laemmerzahl.de`):

```bash
helm upgrade typemill charts/typemill \
  --namespace typemill \
  --set persistence.enabled=true \
  --set persistence.storageClass=longhorn \
  --set persistence.size=2Gi \
  --set typemill.timezone="Europe/Berlin" \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set "ingress.hosts[0].host=typemill.laemmerzahl.de" \
  --set "ingress.hosts[0].paths[0].path=/" \
  --set "ingress.hosts[0].paths[0].pathType=Prefix" \
  --set "ingress.tls[0].secretName=typemill-tls" \
  --set "ingress.tls[0].hosts[0]=typemill.laemmerzahl.de" \
  --set "ingress.annotations.cert-manager\.io/cluster-issuer=letsencrypt-prod"
```

Danach prüfen:
```bash
kubectl -n typemill get ingress
kubectl -n typemill get certificate
```

## Schritt 8: Helm Tests ausführen

```bash
helm test typemill --namespace typemill
```

Erwartet: `test-connection` Pod läuft erfolgreich durch.

## Schritt 9: Aufräumen (nach dem Test)

```bash
helm uninstall typemill --namespace typemill

# PVC manuell löschen (Daten werden gelöscht!)
kubectl -n typemill delete pvc typemill

# Namespace löschen
kubectl delete namespace typemill
```

---

## Troubleshooting

### Pod startet nicht / CrashLoopBackOff
```bash
kubectl -n typemill logs -l app.kubernetes.io/name=typemill --previous
kubectl -n typemill describe pod -l app.kubernetes.io/name=typemill
```

### PVC bleibt in Pending
```bash
kubectl -n typemill describe pvc typemill
# Prüfen ob Longhorn genug Platz hat:
kubectl get nodes -o custom-columns=NAME:.metadata.name,DISK:.status.allocatable.ephemeral-storage
```

### Health-Check schlägt fehl
```bash
# Direkt im Container prüfen:
kubectl -n typemill exec -it deploy/typemill -- curl -s -o /dev/null -w "%{http_code}" http://localhost/tm/login
# Erwartet: 200 oder 302
```
