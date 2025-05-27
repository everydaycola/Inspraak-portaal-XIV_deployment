#!/bin/bash

source modules/config.sh
source modules/colors.sh

source modules/setup_project_variables.sh
source modules/pre_deploy_checks.sh
source modules/setup_vpc_network.sh
source modules/setup_redis_instance.sh
source modules/setup_managed_instance_group.sh
source modules/setup_health_checks.sh
source modules/setup_load_balancer.sh
source modules/setup_bucket.sh
source modules/setup_sql_database.sh

deploy_using_modules() {
    setup_project_variables
    pre_deploy_checks
    setup_vpc_peering
    setup_bucket
    setup_redis_instance
    setup_health_checks
    setup_managed_instance_group
    setup_load_balancer
    setup_sql_database
    setup_firewall_rules

    echo_in_green "Deployment complete. Access your app via the load balancer. http://$(gcloud compute forwarding-rules list --global --format='value(IPAddress)')"
    echo -e "${YELLOW}Accessing the Load balancer may take up to 5 minutes.${ENDCOLOR}"
    echo -e "${YELLOW}You can also go to a specific instance via: http://$(gcloud compute instances list --filter='status=RUNNING' --limit=1 --format='value(networkInterfaces[0].accessConfigs[0].natIP)')${ENDCOLOR}"
}

# Check for the 'deploy' flag
if [ "$1" = "deploy" ]; then
    deploy_using_modules
else
    echo_in_yellow "To deploy the infrastructure, please use the 'deploy' flag: ./deploy.sh deploy"
    echo_in_yellow "For example: ./deploy.sh deploy"
fi
