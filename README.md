# This is the README.md for the deployment side of our project.
This is a complete README on all the scripts in this branch. I will explain how they work, what they do and what else is needed.

## Prerequisites
- A Google Cloud account has been made and authenticated with
- The Google Cloud account has a decent amount of credits
- A project can be found in gitlab

## Setup
Before I start explaining the scripts we need to do a few things to make sure they work.

### SSH keys
#### Step 1: Creating the keys
We will need to create a new SSH key-value pair to access our project in gitlab. 
An example of this would be: `ssh-keygen -t rsa -b 4096 -C "your_email@example.com"`
 Explanation:
 - ssh-keygen: Will generate a new SSH key
 - -t rsa: specifies the key type (RSA)
 - -b 4096: sets the length to 4096 bits
 - -C "your_email@example.example: adds a comment, this is optional but recommended

This will create 2 files. An id_rsa (private key) and id_rsa.pub (public key)

#### Step 2: storing the keys
**Public Key**: 
Now that we have the keys we should place them correctly for our Virtual Machines to access them on startup.

Our public key needs to be stored in gitlab for us to be able to ssh into it and clone our project.

In your gitlab repo go to settings > repository > Deploy keys
Here we'll click "Add new key", give it a title and past the public key in the Key textfield and click Add Key.

Adding it as a deploy key allows our VMs to access and clone this specific repository. This part is essential for automated deployments or any process where our server needs to pull code from gitlab.
Deploy keys are used for read-only access by default which is perfect for our web application.

**Private Key**: 
Our private key will need to be stored in a Google Cloud Secret Manager. We chose for the Secret Manager because this is a Security Best Practice. 
We also needed this Secret Manager because it is centralized which means we don't have to worry about our load balancer creating or destroying instances.

Go to console.cloud.google.com/security/secret-manager
Here we can click on "CREATE SECRET"
Give it a name
Upload the private key or past the secret value and click on "CREATE SECRET"

#### Step 3: The Service account
Our last step is to create a service account which will be used by our instances to access the private keys.

Go to [console.cloud.google.com/iam-admin/iam](https://console.cloud.google.com/iam-admin/serviceaccounts)
```
Select your project
Click on CREATE SERVICE ACCOUNT
Give it a name 
Give it a Service account ID or let it be generated
Click Create and continue
Give it the role of "Secret Manager Secret Accessor"
Click create
```

That's it for the preparation. Now we can go on to our scripts.

## Scripts

### colors.sh
Helps me see the difference between my own comments and the systems comments when a script is being ran.

### config.sh
Contains some needed variables. Makes it easy to configure and make changes whenever we want.

### deploy.sh
This script is divided in a couple different parts. 
Let's start at the top

We start with by importing both the config and colors variables, nothing special there.

Then a simple function to echo in green.

And then we set some google cloud variables which are needed further on in the script.
```
#!/bin/bash

source config.sh
source colors.sh

echo_in_green() {
	echo -e "${GREEN}$1${ENDCOLOR}"
}

echo_in_green "Setting gcloud properties..."
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE
echo_in_green "Properties set."
```
***

**Checks**: 
Then we go on to do a couple checks to make sure everything is the way we want it to be before starting the configurations.

This is a simple function which checks if the gcloud command exists on the system. If not it will throw an error and exit
```
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists gcloud; then
	echo "Error: gcloud CLI is not installed"
	exit 1
fi
```

This will check if you are authenticated
```
if ! gcloud auth list --format="value(account)" | grep -q "@"; then
	echo "Error: You are not authenticated. Run: gcloud auth login"
	exit 1
fi
```

Check if the google cloud "project" variable has a value
```
# Check if "project" has a value
if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
	echo "Error: No GCP project is set. Run gcloud config set project [PROJECT_ID]"
	exit 1
fi
```

This check if the google cloud compute/zone variable has a value
```
if [ -z "$(gcloud config get-value compute/zone 2>/dev/null)" ]; then
	echo "Error: No compute zone is set. Run: gcloud config set compute/zone [ZONE]"
	exit 1
fi
```
***
**Instance template**:
This is the template that will be used by EACH instance that will be created in this project.
We will be using a load balancer which makes it important that we have this template for whenever a new VM gets spun up

The image family is just which OS you want to use like ubuntu and the image project is where the image is located.
The --metadata will be used to pass a startup script which will be executed on EACH VM instance at startup. We'll look at this one later on.
```
gcloud compute instance-templates create "$INSTANCE_TEMPLATE_NAME" \
	--machine-type="$MACHINE_TYPE" \
	--region="$REGION" \
	--image-family="$IMAGE_FAMILY" \
	--image-project="$IMAGE_PROJECT" \
	--metadata=startup-script="$(cat $STARTUP_SCRIPT)" \
	--tags=http-server,https-server \
	--scopes=cloud-platform
```

**Managed Instance Group**: 
This creates a group of identical VM instances based on their instance template. It manages them and makes sure they are running and healthy
```
gcloud compute instance-groups managed create "$INSTANCE_GROUP_NAME" \
	--base-instance-name=web-instance \
	--size=$MIN_INSTANCES \
	--template="$INSTANCE_TEMPLATE_NAME" \
	--zone="$ZONE"
```

**Autoscaler**:
This automatically adjusts the number of instances in the MIG based on CPU utilization. It will be used to horizontally scale our application.
```
gcloud compute instance-groups managed set-autoscaling "$INSTANCE_GROUP_NAME" \
    --zone="$ZONE" \
    --min-num-replicas="$MIN_INSTANCES" \
    --max-num-replicas="$MAX_INSTANCES" \
    --target-cpu-utilization="$TARGET_CPU_UTILIZATION" \
    --cool-down-period=60
```

**Health Check Creation**:
This Health Check will be used by the load-balancer to determine if the instances are healthy. This ensures that the load balancer only routes traffic to healthy instances.
```
gcloud compute health-checks create http "$HEALTH_CHECK_NAME" \
    --check-interval=30s \
    --timeout=5s \
    --unhealthy-threshold=3 \
    --healthy-threshold=2 \
    --port=80
```

**Load Balancer**:
***
*Backend service*
Creates a backend service that distributes the traffic to the instance in the MIG. 
```
gcloud compute backend-services create "$BACKEND_SERVICE_NAME" \
    --protocol=HTTP \
    --health-checks="$HEALTH_CHECK_NAME" \
    --global
```
*Adding the Instance Group to the Backend Service*:
Adds the MIG to the backend service
```
gcloud compute backend-services add-backend "$BACKEND_SERVICE_NAME" \
    --instance-group="$INSTANCE_GROUP_NAME" \
    --instance-group-zone="$ZONE" \
    --global
```

*URL Map Creation*:
Creates a URL mat that routes traffic to the backend service
```
gcloud compute url-maps create "$URL_MAP_NAME" --default-service="$BACKEND_SERVICE_NAME"
```

*HTTP-proxy creation*:
Creates a HTTP proxy that receives incoming requests and forwards them to the URL map
```
gcloud compute target-http-proxies create "$HTTP_PROXY_NAME" --url-map="$URL_MAP_NAME"
```

*Global Forwarding Rule Creation*:
Creates a global forwarding rule, it defines the external IP address and port that the load balancer listens on
```
gcloud compute forwarding-rules create "$FORWARDING_RULE_NAME" \
    --global \
    --target-http-proxy="$HTTP_PROXY_NAME" \
    --ports=80
```

*Firewall Rule Creation*
Creates a firewall rule, it controls network traffic to our instances and prevent unauthorized access
```
gcloud compute firewall-rules create "$FIREWALL_RULE_NAME" \
    --allow tcp:80,tcp:5000 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server \
    --description "Allow HTTP traffic"
```
And that's all for the deployment

### destroy.sh
Is actually just a big script that deletes everything we did in the deploy.sh

### startup-script.sh
This script will be executed on each instance when they start up.

It is also divided in a couple parts

**SSH Key Setup**
Here we retrieve the private SSH key from the Google Secret Manager.
We configure the SSH to use this key for connecting to gitlab and then test the connection.
```
mkdir -p ~/.ssh
chmod 700 ~/.ssh

echo "Retrieving and decoding SSH key..."
gcloud secrets versions access latest --secret=gitlab_deploy_key | tr -d '\r\n' | base64 --decode >/root/.ssh/gitlab_key
echo "SSH key retrieved and decoded."
chmod 600 ~/.ssh/gitlab_key

cat <<EOF >~/.ssh/config
Host gitlab.com
    IdentityFile ~/.ssh/gitlab_key
    StrictHostKeyChecking no
EOF
chmod 600 ~/.ssh/config

echo "Testing SSH connection..."
ssh -T git@gitlab.com || echo "SSH connection failed"
echo "SSH connection successful."
```

**Installing packages**:
Here we install git, nginx and the .NET SDK
```
apt-get update
apt-get install -y nginx

apt-get install -y git

echo "Checking Git installation..."
which git || {
    echo "Git is not installed"
    exit 1
}
echo "Git is installed."

wget https://packages.microsoft.com/config/ubuntu/20.04/prod.list
mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | apt-key add -
apt-get update
apt-get install -y dotnet-sdk-8.0
```

**Repository Cloning**
Clones our gitlab repo into the ./myapp folder
```
echo "Cloning repository..."
git clone git@gitlab.com:kdg-ti/integratieproject-1/202425/14_team-14/development.git ./myapp || {
    echo "Git clone failed"
    exit 1
}
echo "Repository cloned successfully."
```

**.NET version check and HOME env variable**:
This verifies the .NET installation, if it returns nothing it will stop the script.
We also set the HOME directory to /root because it was needed for dotnet to work
```
dotnet --version || {
    echo ".NET installation failed"
    exit 1
}

echo "Setting HOME environment variable..."
export HOME=/root
```

**.NET app build**:
If all previous checks worked properly we can confidently build the app
```
echo "Building .NET application..."
dotnet publish -c Release -o ./myapp/out || {
    echo "Dotnet build failed. Please check the logs for errors."
    exit 1
}
echo ".NET application built successfully."
```

**Nginx configuration**:
- Creates an nginx configuration file (/etc/nginx/sites-available/myapp) -> it acts as a reverse proxy forwarding requests to our .NET app runing on port 5000
- Creates a symbolic link to enable the configuration
- Removes the default nginx configuration -> Prevents conflicts
- Tests the nginx configuration -> ensures it is running correctly
- restarts the service
```
cat <<EOF >/etc/nginx/sites-available/myapp
server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default

sleep 2
nginx -t || {
    echo "Nginx configuration failed"
    exit 1
}

systemctl restart nginx
```

**.NET Application Startup**: 
Starts our .NET application in the background and redirects the applications output to /var/log/myapp.log
```
cd ./myapp/out
nohup dotnet UI-MVC.dll >/var/log/myapp.log 2>&1 &
```