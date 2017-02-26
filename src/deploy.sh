#!/bin/bash
set -e -u

HIGHLIGHT_COLOR='\e[92m'
NO_COLOR='\e[0m'

print_colored_text () {
	echo -e "${HIGHLIGHT_COLOR}$1${NO_COLOR}"
}

usage() { echo "Usage: $0 -s|--subscription-id <subscriptionId> -r|--ressource-group-name <resourceGroupName> -l|--resource-group-location <resourceGroupLocation>" 1>&2; exit 1; }

subscriptionId=''
resourceGroupName=''
resourceGroupLocation=''
deploymentName="$(date -u +%Y.%m.%d_%H.%M.%S.%3N)"

TEMP=`getopt -o s:r:l: --long subscription-id:,ressource-group-name:,resource-group-location: -n "$0" -- "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -s|--subscription-id)
            case "$2" in
                "") shift 2 ;;
                *) subscriptionId=$2 ; shift 2 ;;
            esac ;;
        -r|--ressource-group-name)
            case "$2" in
                "") shift 2 ;;
                *) resourceGroupName=$2 ; shift 2 ;;
            esac ;;
        -l|--resource-group-location)
            case "$2" in
                "") shift 2 ;;
                *) resourceGroupLocation=$2 ; shift 2 ;;
            esac ;;
        --)
            shift;
            break ;;
        *)
            echo "Not a recognized parameter"
            usage
            ;;
    esac
done

# Template file path
templateFilePath="template.json"

# Parameter file path
parametersFilePath="parameters.json"

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ]; then
	echo "Either one of subscriptionId, resourceGroupName is empty"
	usage
fi

# Login to azure
print_colored_text 'Azure login...'
az login 1>/dev/null

# Set the default subscription id
print_colored_text 'Setting subscription...'
az account set --subscription "$subscriptionId"

# Check for existing resource group
print_colored_text 'Checking if resource group is existing...'
doesResourceGroupExist="$(az group exists -n $resourceGroupName)"
if [ $doesResourceGroupExist = "true" ];
then
	print_colored_text 'Using existing resource group'
else 
	print_colored_text 'Creating a new resource group...'

	if [ -z "$resourceGroupLocation" ]; then
		echo "resourceGroupLocation is required to create a new resource group"
		usage
	fi

	az group create -n $resourceGroupName -l $resourceGroupLocation --tags 'purpose=build' 1>/dev/null
fi

# Start deployment
print_colored_text 'Starting deployment...'
json_data=$(az group deployment create\
    --name $deploymentName\
    --resource-group $resourceGroupName\
    --template-file $templateFilePath\
    --parameters "@$parametersFilePath")

virtualMachineId=$(python3 -c "import sys, json; print(json.loads(sys.argv[1])['properties']['dependencies'][0]['id']); sys.exit(0);" "$json_data")

print_colored_text 'Restarting the Virtual Machine'
az vm restart --ids $virtualMachineId 1>/dev/null

print_colored_text 'Finished deployment...'