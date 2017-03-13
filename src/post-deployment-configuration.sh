#!/bin/bash -eu

export DEBIAN_FRONTEND=noninteractive

MAIN_TITLE_COLOR='\e[92m'
SECONDARY_TITLE_COLOR='\e[96m'
NO_COLOR='\e[0m'

print_colored_text () {
	echo -e "${1}$2${NO_COLOR}"
}

print_main_title () {
    print_colored_text ${MAIN_TITLE_COLOR} "$1"
}

print_secondary_title () {
    print_colored_text ${SECONDARY_TITLE_COLOR} "\t$1"    
}

usage () {
    echo "Usage: $0 -u|--vsts-url <vstsUrl> --agent-name <agentName> --agent-pool <agentPool> --admin-username <adminUsername> -p|--personal-access-tokee <personalAccessToken>" 1>&2;
    exit 1;
}

vstsUrl=''
agentName=''
agentPool=''
pat=''
adminUsername=''

vstsBuildAgentVersion='2.112.0'

# Reading options
TEMP=`getopt -o u:p: --long vsts-url:,agent-name:,agent-pool:,admin-username:,personal-access-token: -n "$0" -- "$@"`
eval set -- "$TEMP"

while true ; do
    case "$1" in
        -u|--vsts-url)
            case "$2" in
                "") shift 2 ;;
                *) vstsUrl=$2 ; shift 2 ;;
            esac ;;
        --agent-name)
            case "$2" in
                "") shift 2 ;;
                *) agentName=$2 ; shift 2 ;;
            esac ;;
        --agent-pool)
            case "$2" in
                "") shift 2 ;;
                *) agentPool=$2 ; shift 2 ;;
            esac ;;
        -p|--personal-access-token)
            case "$2" in
                "") shift 2 ;;
                *) pat=$2 ; shift 2 ;;
            esac ;;
        --admin-username)
            case "$2" in
                "") shift 2 ;;
                *) adminUsername=$2 ; shift 2 ;;
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

if [ -z "$vstsUrl" ] || [ -z "$agentName" ] || [ -z "$agentPool" ] || [ -z "$pat" ] || [ -z "$adminUsername" ]; then
	echo "Either one of vstsUrl, agentName, agentPool, pat, adminUsername is empty"
	usage
fi

print_main_title 'Updating apt-get...'
sudo apt-get -qq -y update

print_main_title 'Installing zip...'
sudo apt-get -qq -y install zip 1>/dev/null

print_main_title 'Installing and configuring VSTS build agent...'
print_secondary_title 'Installing libunwind8 libcurl3...'
sudo apt-get -qq -y install libunwind8 libcurl3 1>/dev/null
# Azure is running this script as 'root' but the VSTS build agent needs to be installed as '$adminUsername'
su - $adminUsername <<HERE_DOCUMENT_VSTS_AGENT
cd ~
echo -e "${SECONDARY_TITLE_COLOR}\tDownloading VSTS build agent...${NO_COLOR}"
wget -q "https://github.com/Microsoft/vsts-agent/releases/download/v${vstsBuildAgentVersion}/vsts-agent-ubuntu.16.04-x64-${vstsBuildAgentVersion}.tar.gz"
echo -e "${SECONDARY_TITLE_COLOR}\tCreating myagent directory${NO_COLOR}"
mkdir myagent && cd myagent
echo -e "${SECONDARY_TITLE_COLOR}\tExtracting build agent...${NO_COLOR}"
tar -zxf ~/vsts-agent-ubuntu.16.04-x64-${vstsBuildAgentVersion}.tar.gz
echo -e "${SECONDARY_TITLE_COLOR}\tConfiguring VSTS build agent...${NO_COLOR}"
./config.sh\
    --url $vstsUrl\
    --agent "$agentName"\
    --pool "$agentPool"\
    --acceptteeeula\
    --auth PAT\
    --token $pat\
    --replace\
    --unattended 1>/dev/null
echo -e "${SECONDARY_TITLE_COLOR}\tConfiguring the VSTS build agent to run as a service with SystemD...${NO_COLOR}"
sudo ./svc.sh install 1>/dev/null
echo -e "${SECONDARY_TITLE_COLOR}\tStarting the VSTS build agent...${NO_COLOR}"
sudo ./svc.sh start 1>/dev/null
echo -e "${SECONDARY_TITLE_COLOR}\tCreating uninstall script...${NO_COLOR}"
echo "sudo ./svc.sh stop
sudo ./svc.sh uninstall
./config.sh remove" > ./uninstall.sh
chmod +x ./uninstall.sh
HERE_DOCUMENT_VSTS_AGENT

print_main_title 'Installing and configuring Docker...'
sudo apt-get -qq -y --no-install-recommends install curl apt-transport-https ca-certificates curl software-properties-common 1>/dev/null
curl -fsSL https://apt.dockerproject.org/gpg | sudo apt-key add - 1>/dev/null
sudo add-apt-repository "deb https://apt.dockerproject.org/repo/ ubuntu-$(lsb_release -cs) main"
sudo apt-get -qq -y update 1>/dev/null
sudo apt-get -qq -y install docker-engine 1>/dev/null
sudo groupadd -f docker
sudo adduser $adminUsername docker 1>/dev/null

print_main_title 'Installing AWS CLI...'
sudo apt-get -qq -y install python3-dev 1>/dev/null
# Azure is running this script as 'root' but pip and the AWS CLI need to be installed as '$adminUsername'
su - $adminUsername <<HERE_DOCUMENT_AWS_CLI
cd ~
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py --user 1>/dev/null
pip install awscli --upgrade --user 1>/dev/null
HERE_DOCUMENT_AWS_CLI

print_main_title 'Configuration completed'