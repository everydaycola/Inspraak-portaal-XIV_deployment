# Integratieproject 1 | 2024-2025

### Team 14_

## Inspraak portaal XIV [IP14]

Op ons platform IP14 kan een organisatie, gemeenschap, club, of eender wie anders, een account aanmaken, Hiermee kan u Panels hosten. 
Ons platvorm is vooral gemaakt voor het aanmaken van burgerpanels maar kan ook gebruikt worden voor kleinere panels. 
We bieden U een tool om uw panel samen te stellen, U kan mensen uitnodigen op basis van verschillende criteria. 
Wanneer de uitgenodigde beslissen deel te nemen aan het panel aan uw panel, zal u via ons een project pagina kunnen samenstellen waar u posts kunt maken en kunt communiceren met het panel. 
U kunt hier vergaderingen inplannen en stemming houden.

## Ons team
- [Ilja Nachtergaele](https://www.linkedin.com/in/ilja-nachtergaele-8665b622a/)
- [Stijn Similon](https://www.linkedin.com/in/stijn-similon-b86a27332/)
- [Tibo Eycken](https://www.linkedin.com/in/tibo-eycken-b81aaa1a3/)
- [Zachary Van De Staey](https://www.linkedin.com/in/zachary-van-de-staey-04ba56229/)

--- 


# Deployment Scripts - Google Compute Engine (GCE)

Dit project bevat bash-scripts voor het automatisch opzetten, beheren en verwijderen van een volledige infrastructuur op **Google Compute Engine (GCE)**.

---

## Functionaliteiten

### Vereist
- Opzetten van de volledige omgeving
- Volledig verwijderen van de omgeving
- Deployen van een nieuwe versie (upgrade)

### Extra's
- Backup en restore van de database
- Monitoring met Ops Agent
- Custom domeinnaam
- Zero-downtime deployment (Zie CI-CD in .NET applicatie)

---

## Vereisten

Zorg ervoor dat volgende tools geïnstalleerd zijn:
- **Bash** (4.0+) [Installatie Git Bash](https://git-scm.com/downloads)
- **Google Cloud SDK (gcloud)** – [Installatie](https://cloud.google.com/sdk/docs/install)
- **curl** – Voor API-aanroepen [Installatie](https://curl.haxx.se/)
- Een actief **Google Cloud-account** [Google Cloud](https://cloud.google.com/?hl=en)
## Voorbereiding
### Inloggen bij gcloud
1. open een terminal en gebruik `gcloud auth login`
2. Volg de gevraagde stappen
### Billing account
(als je al een billing account hebt ga naar 'manage billing accounts')
Ga in gcloudconsole.cloud.google.com naar billing > Create account (als je al een billing account hebt druk 'manage billing accounts') geef een naam en link aan een payment profiel of maak een nieuw profiel

Bewaar deze Billing Account ID

### Opzetten van het project
Gebruik commando `git clone https://gitlab.com/kdg-ti/integratieproject-1/202425/14_team-14/deployment.git` om het project te installeren

### Toevoegen Secrets
Maak een nieuw bestand met de naam secrets.sh en zet deze in de map 'secrets'.

Kopieer deze inhoud naar dit bestand
```bash
#!/bin/bash

# --- Cloud SQL ---
CLOUD_SQL_PASSWORD="" # bijvoorbeeld postgres
CLOUD_SQL_USER="" # bijvoorbeeld postgres

# --- Billing Account ---
BILLING_ACCOUNT_ID=""

# --- SENDGRID API Keys ---
SENDGRID_API_KEY=""

# --- provincies-in-cijfers Keys ---
PINC_API_KEY=""

# --- Application Bucket Name ---
APP_BUCKET=""

# --- Cloudflare API Token ---
CLOUDFLARE_API_TOKEN=""
CLOUDFLARE_ZONE_ID=""

# --- Gitlab Keys ---
GITLAB_TOKEN=""
GITLAB_PROJECT_ID=""
```

Te kiezen:  een **CLOUD_SQL_PASSWORD**, **CLOUD_SQL_USER** en **APP_BUCKET**

Plak hier ook het verkregen **BILLING_ACCOUNT_ID** van de stap hiervoor

#### Stappen Domeinnaam + SSL
1. **API key voor cloudflare** 
Maak een account bij https://cloudflare.com

Vraag een Domeinnaam aan bij een service-provider. In deze tutorial werken we met CloudFlare

In Cloudflare ga naar profiel > API Tokens 
Klik Create Token > Edit zone DNS
onder Zone Resources kies het juiste domein en klik Continue to summary

Klik Create Token en kopieer deze in het secrets.sh bestand bij **CLOUDFLARE_API_TOKENS=""**

2. **Cloudflare Zone ID**

Ga naar Account Home en klik op je domeinnaam
Scroll naar beneden en onder API kopieer Zone ID naar - **CLOUDFLARE_ZONE_ID=""**

3. **Installeren SSL certificate en key**

Vanuit Account Home klik op je domeinnaam
Ga naar SSL/TLS > Origin Server > Create Certificate 
voeg je domeinnaam en \*.domeinnaam toe aan de hostnames en klik create
Kopieer de Origin Certificate naar bestand **cf-cert.pem**
Kopieer de private key naar bestand **cf-key.pem**
Plaats beide bestanden ook in de secrets map

4. **PINC API**

Vraag een API aan door een mail te sturen naar info@provincies.incijfers.be en voeg deze toe bij **PINC_API_KEY=""**

#### API key mailserver
In deze tutorial werken we met Sendgrid.

Maak hier een account en ga naar API Keys > API Key Management

Maak hier een primary API key aan
Kopieer deze API key naar 
**SENDGRID_API_KEY=""**

Kopieer deze Secret Key naar
**MJ_PRIVATE_API_KEY=""**

### GitLab Personal Access Token toevoegen

Om deploy keys en CI/CD variabelen automatisch te kunnen instellen, heb je een GitLab token nodig:

1. Ga naar [je GitLab tokens pagina](https://gitlab.com/-/profile/personal_access_tokens)
2. Geef de token een naam, kies een geldigheidsdatum
3. Selecteer scope `api`
4. Klik op "Create token" en kopieer de token direct
5. Voeg deze toe aan `secrets.sh`:

```bash
GITLAB_TOKEN=""
```

### Gitlab project ID
Ga naar gitlab > de repo die je zult deployen > Settings > General 

Kopieer hier het project ID en plak deze naast `GITLAB_PROJECT_ID=""` in de secrets.sh

## Projectstructuur

```bash
scripts/
├── modules/                          
│   ├── add_lb_ip_to-cloudflare.sh
|   ├── colors.sh                         
|   ├── config.sh  
│   ├── create_ssl_cert.sh
│   ├── pre_deploy_checks.sh
│   ├── setup_bucket.sh
│   ├── setup_health_checks.sh
│   ├── setup_load_balancer.sh
│   ├── setup_managed_instance_group.sh
│   ├── setup_project_variables.sh
│   ├── setup_redis_instance.sh
│   ├── setup_sql_database.sh
│   └── setup_vpc_network.sh
│
├── secrets/
|   ├── secrets.sh                        
|   ├── cf-cert.pem
|   ├── cf-key.pem                           
|
├── vmScripts/                        
|   ├── startup-script.sh            
|
├── .gitignore                        
├── delete_project.sh                 
├── deploy_using_modules.sh          
├── destroy.sh                        
├── initial_setup_script.sh         
├── restore_cloud_sql_backup.sh      
├── upgrade_current_code.sh         
README.md            
README.adoc            
```

## Configuratie modules/config.sh
**BELANGRIJK:** pas volgende lijnen aan

```bash
PROJECT_ID=""                # LET OP: Dit hoort uniek te zijn dus voeg indien nodig een aantal cijfers toe (voorbeeld ons-eerste-project-1a)
PROJECT_NAME=""              # Pas aan naar een naam naar keuze
ZONE="europe-west1-b"        # laat zo of kies een andere, deze zones zijn te vinden met commando `gcloud compite zones list`
REGION="europe-west1"        # Laat zo of kies een andere, regios te vinden met `gcloud compute regions list`
```

## Aanpassingen vmScripts/startup-script.sh

Vervang volgende variabelen
```bash
# Variables
GIT_REPO=""                                 # Plaats hier de link van je gitlab project
GIT_BRANCH=""                               # Plaats hier de branch die je wilt deployen
DOMAIN_NAME=""                              # Geef je domein-naam in
```

Nu dit allemaal gebeurt is kunnen we onze applicatie deployen

# Runnen Scripts vanuit de `scripts` map
Ga naar map scripts met `cd scripts`

## Alles opzetten + deployen
Als je heel de google cloud infrastructuur wilt opzetten en je applicatie wilt deployen run dan `./initial_setup_script.sh`

## Alleen deployen
Stel je hebt je google cloud omgeving al opgezet dan kun je ook enkel deployen met `./deploy_using_modules.sh deploy`

## Een backup restoren
Als je je databank wilt terugdraaien naar een backup run dan `./restore_cloud_sql_backup.sh`

## Vernieuwen code
Stel dat er een update in de code is gebeurd en je wilt deze op je instanties krijgen run dan `./upgrade_current_code.sh` (zal een rolling update doen) 

## Deployment neer halen
Als je je deployment offline wilt halen kan dit met `./destroy.sh`

## Verwijderen Google Project
Als je heel je google cloud project wilt verwijderen run dan `./delete_project.sh`

## Veelvoorkomende problemen

### ERROR: "Cannot delete an inactive project"
- **Oorzaak**: Het project is al gemarkeerd voor verwijdering of je hebt geen rechten.
- **Oplossing**: Controleer met `gcloud projects describe $PROJECT_ID`.

### API access denied
- **Oorzaak**: Ontbrekende of foute API keys.
- **Oplossing**: Controleer `secrets.sh` en of alle variabelen correct ingevuld zijn.

## Schatting Maandelijkse Kost

| service_display_name       | name                                                        | quantity | region       | service_id        | sku           | total_price_EUR |
|----------------------------|-------------------------------------------------------------|----------|--------------|-------------------|---------------|-----------------|
| Secret Manager             | Secret version replica storage                            | 10       | global       | EE82-7A5E-775C    | 7756-ADEF     | 0.21118         |
| VMs (Compute Engine)       | E2 Instance:Core running in EMEA                          | 1460     | europe-west2 | 6F81-5844-46A     | 9FE0-8F60     | 30.8232         |
| VMs (Compute Engine)       | E2 Instance:Ram running in EMEA                           | 5840     | europe-west2 | 6F81-5844-46A     | F268-6CE7     | 16.52625        |
| VMs (Compute Engine)       | Balanced PD Capacity                                        | 20       | europe-west2 | 6F81-5844-46A     | 6AE1-525F     | 1.7598          |
| PostgreSQL (Cloud SQL)     | Cloud SQL for PostgreSQL Zonal - IOPS in EMEA             | 1460     | europe-west2 | 9662-B51E-5089    | 2154-E036     | 53.05621        |
| PostgreSQL (Cloud SQL)     | Cloud SQL for PostgreSQL Zonal - RAM in EMEA              | 5475     | europe-west2 | 9662-B51E-5089    | 8A88-5E4E     | 33.72217        |
| PostgreSQL (Cloud SQL)     | Cloud SQL for PostgreSQL Zonal - Standard storage in EMEA | 73000    | europe-west2 | 9662-B51E-5089    | B14E-2B60     | 13.931          |
| Redis (Cloud Memorystore)  | Redis Capacity Basic M2 Belgium                           | 7300     | europe-west2 | 5AF5-2C11-0467    | AC1B-F435     | 32.9169        |
| Static IP (Networking)     | External IP Charge on a Standard VM                       | 1        | global       | 6F81-5844-46A     | C054-7F72     | 0               |
| Static IP (Networking)     | External IP Charge on a Spot/Preemptible VM               | 0        | global       | 6F81-5844-46A     | 4AF8-7C1F     | 0               |
| Static IP (Networking)     | Static Ip Charge                                          | 0        | europe-west2 | 6F81-5844-46A     | 66A2-68EA     | 0               |
| Load Balancer (Networking) | Regional External Application Load Balancer Inbound Data Processing for Belgium (europe-west1) | 100      | europe-west2 | E505-509A-58F9    | 4CA1-8FBD     | 0.70392         |
| Load Balancer (Networking) | Regional External Application Load Balancer Outbound Data Processing for Belgium (europe-west1) | 100      | europe-west2 | E505-509A-58F9    | 6447-DBD0     | 0.70392         |
| Load Balancer (Networking) | Regional External Proxy Network Load Balancer Forwarding Rule Minimum for Belgium (europe-west1) | 1        | europe-west2 | E505-509A-58F9    | A1EB-4344     | 16.05818        |
| Bucket (Cloud Storage)     | Standard Storage Belgium                                  | 100      | europe-west2 | 95FF-2EF5-5541    | A703-5CB6     | 1.7598          |
| **Total Price:** |                                                             |          |              |                   |               | **202.1769** |

Deze prijzen zijn een **schatting** in EURO, verkregen op **27/05/2025** via de Google Cloud Service 'Cost Estimation'.

Om kosten te drukken of performantie te verhogen kunnen wijzigingen aangebracht worden in het configuratiebestand. Om zelf aanpassingen en bijhorende kosten te kunnen bekijken gebruik dan [Google Cloud Cost Estimation](https://cloud.google.com/products/calculator)

## Auteur

Deze scripts werd geschreven door Tibo Eycken in het kader van het IP1-project aan KdG.