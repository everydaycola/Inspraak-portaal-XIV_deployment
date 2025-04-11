# Enabel Certificate Manager API
- in Google Cloud Console, go to API Library
- Search for "Certificate Manager API" ane enable it

# Create a DNS Authorization
- Run following gcloud command (USE YOUR DOMAINNAME)
```Bash
gcloud certificate-manager dns-authorizations create my-dns-auth \
    --domain="ip14.be"
```
- you will need a CNAME record to add to our domain's DNS settings
```Bash
gcloud certificate-manager dns-authorizations describe my-dns-auth
```
- Copy the CNAME - Something like   
"data: 0985a32b-f07c-409e-abcd-fa390f184464.3.authorize.certificatemanager.goog.
name: _acme-challenge.ip14.be."
- Go to DNS provider (in my case GoDaddy)
- Add the CNAME record - Wait for DNS propagation might take a while

# Create Google Managed Certificate
- Run following Command
```Bash
gcloud certificate-manager certificates create my-cert \
    --domains="ip14.be,*.ip14.be" \
    --dns-authorizations=my-dns-auth
```
- This creates a certificate for both your domain and a wildcard
- GCloud will automatically handle the certificate provisioning and renewal

# Create a Certificate MAP
- Certificate maps are used to associate certificates with hostnames
- Run following command
```Bash
gcloud certificate-manager maps create my-map
```

# Create Cert Map Entries
- Create Entries for Both domain and wildcard domain
```Bash
gcloud certificate-manager maps entries create my-entry1 \
    --map=my-map \
    --certificates=my-cert \
    --hostname="example.com"

gcloud certificate-manager maps entries create my-entry2 \
    --map=my-map \
    --certificates=my-cert \
    --hostname="*.example.com"
```

# Associate The Cert Map with HTTPS proxy
(if proxy already exists)
```bash
gcloud compute target-https-proxies update your-https-proxy \
    --certificate-map=my-map
```