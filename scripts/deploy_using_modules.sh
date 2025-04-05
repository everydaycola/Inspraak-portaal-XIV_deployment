#!/bin/bash

source config.sh
source colors.sh

source modules/setup_project_variables.sh
source modules/pre_deploy_checks.sh
source modules/setup_vpc_network.sh
source modules/setup_managed_instance_group.sh
source modules/setup_health_checks.sh
source modules/setup_load_balancer.sh
source modules/setup_sql_database.sh

main() {
    setup_project_variables
    pre_deploy_checks
    setup_vpc_network
    setup_vpc_peering
    setup_managed_instance_group
    setup_health_checks
    setup_load_balancer
    setup_sql_database
    setup_firewall_rules
}

main

echo_in_green "Deployment complete. Access your app via the load balancer. http://$(gcloud compute forwarding-rules list --global --format='value(IPAddress)')"
echo -e "${YELLOW}Accessing the Load balancer may take up to 5 minutes.${ENDCOLOR}"
echo -e "${YELLOW}You can also go to a specific instance via: http://$(gcloud compute instances list --filter='status=RUNNING' --limit=1 --format='value(networkInterfaces[0].accessConfigs[0].natIP)')${ENDCOLOR}"
