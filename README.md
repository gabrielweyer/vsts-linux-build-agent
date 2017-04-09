# Provision a Linux Docker VSTS agent with the AWS CLI capability

This project automates the creation of a Linux Docker VSTS agent with the AWS CLI capability.

The provisioning rely on the [Azure Resource Manager][arm].

A use case for this setup would be an ASP.NET Core codebase using VSTS as a source control, build and deployment system and having the requirement to deploy the web application to AWS Beanstalk.

.NET being a [second][dotnet-beanstalk-limitations] [class][dotnet-beanstalk-bug] citizen on Beanstalk, I recommend to create Docker images so that you can take full advantage of the platform.

## Prerequisites

Create:

- An [Azure account][azure-account] if you don't have one already.
- A [VSTS account][vsts-account] if you don't have one already.

Install:

- [Bash on Ubuntu on Windows (WSL)][install-wsl] - makes it easier to generate SSH keys and SSH into the build agent later on
  - This step is not required if you're on OS X or Linux
- [Azure CLI 2.0][azure-cli-2]

## Generate a SSH public and private key pair

You can read detailed instructions [here][generate-ssh-keys] if required but this section should be sufficient.

### Create a new key

```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/<filename-for-the-private-key> -C "<human-name-for-the-key>" -N <super-strong-passphrase>
ssh-add ~/.ssh/<filename-for-the-private-key>
```

> Azure [requires][azure-ssh-key-pairs-requirement] at least 2048-bit, ssh-rsa format public and private keys. This is handled by the options `-t rsa -b 2048`.

- `<filename-for-the-private-key>`: you might end up having multiple key pairs for different purpose / environments. Choose a meaningful name.
- `<human-name-for-the-key>`: will be part of the public key. It's useful to identify what a SSH public key is used for.
- `<super-strong-passphrase>`: generate it randomly and store it securely. The longer the passphrase is the better.

### Import existing key

- Create a new file in the `~/.ssh/` directory with the content of the `Private Key`.
- Type `ssh-add ~/.ssh/<filename-for-the-private-key>`.

### Troubleshooting adding the key pair

If you get this error when typing `ssh-add`:

```bash
Could not open a connection to your authentication agent.
```

Run this:

```bash
eval "$(ssh-agent -s)"
```

### Create a config file

This section is optional. It allows you to SSH into the build agent by using an alias (i.e. `ssh <build-agent-alias>`).

You can refer to the [Azure documentation][create-ssh-config-file].

## Retrieve the required parameters

These parameters will need to be configured in `.src/parameters.json`.

### Admin account for Virtual Machine

- `adminUsername`: favor a randomly generated name.
- `adminPublicKey`:
  - `ssh-keygen -y -f ~/.ssh/<filename-for-the-private-key> > ~/.ssh/<filename-for-the-private-key>.pub`
  - `cat <filename-for-the-private-key>.pub`
  - Copy the output to the parameter value

### Collect VSTS information

- `vstsUrl`: base URL of your VSTS account (`https://<your-account>.visualstudio.com/` for example).
- `agentName`: give your agent a meaningful name (`docker-linux` for example).
- `agentPool`: name of the the VSTS pool.
- `personalAccessToken`:
  - [How to get a Personal Access Token][how-to-get-pat].
  - Confirm the user used to generate the `PAT` [has the required permissions][pat-admin].
  - Give it a meaningful name: `Team Name Build Agent` for example
  - Choose the longest possible expiry (one year currently)
  - You only need a single scope: `Agent Pools (read, manage)`
- `virtualMachineName`: give your Virtual Machine a meaningful name (`docker-build-agent-vm` for example).

### Optional configurations

Depending on your requirements you can change the value of `storageAccountType` and `diagnosticsStorageAccountType`.

The build agent has been configured to use a static public IP address so that it can be whitelisted if you wish to run databases migrations from it when deploying. It also makes it easier to SSH into it.

The post deployment script needs to be publicly accessible on the internet. I'm using a [Gist][extensions-gist], if you decide to modify it you'll need to host it somewhere and modify the `./src/template.json` accordingly. **Warning**: do not harcode any credentials in this file!

## Deploy the build agent

```bash
./src/deploy.sh -s <azure-subscription-id> -r <desired-resource-group-name> -l <location>
```

- `azure-subscription-id`: you can find your subscription id in the [Azure portal][azure-portal], select the `Subscriptions` blade on the left.
- `desired-resource-group-name`: give your Resource Group a meaningful name (`docker-build-rg` for example).

**Note**: the script will prompt you to sign in into Azure.

Get a cup of coffee, the script will take around 5 minutes to deploy all the required components!

## Uninstall and unregister a build agent

If you don't want your build agent to remain as `Offline` in the `Agent Pool` when deleting the Virtual Machine you can uninstall and unregister the build agent.

SSH into the build agent and type:

```bash
cd myagent
./uninstall.sh
```

**Note**: you'll need to provide your `PAT`.

## Troubleshooting the extension

If the extensions (the post deployment script contained in `./src/post-deployment-configuration.sh`) fail to execute you can refer to this [troubleshooting][troubleshooting-extensions] section.

**TLDR**:

- ssh into the build agent
- `sudo su`
- `cat /var/lib/waagent/custom-script/download/0/stderr`
- `cat /var/lib/waagent/custom-script/download/0/stdout`

[arm]: https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-overview
[dotnet-beanstalk-limitations]: http://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html#concepts.platforms.net
[dotnet-beanstalk-bug]: http://stackoverflow.com/questions/40127703/aws-elastic-beanstalk-environment-in-asp-net-core-1-0
[azure-account]: https://azure.microsoft.com/en-au/free/
[vsts-account]: https://www.visualstudio.com/team-services/
[install-wsl]: https://msdn.microsoft.com/en-au/commandline/wsl/install_guide
[azure-cli-2]: https://docs.microsoft.com/en-us/cli/azure/install-az-cli2
[generate-ssh-keys]: https://docs.microsoft.com/en-us/azure/virtual-machines/virtual-machines-linux-mac-create-ssh-keys
[azure-ssh-key-pairs-requirement]: https://docs.microsoft.com/en-us/azure/virtual-machines/virtual-machines-linux-mac-create-ssh-keys#disable-ssh-passwords-by-using-ssh-keys
[lastpass]: https://lastpass.com/
[create-ssh-config-file]: https://docs.microsoft.com/en-us/azure/virtual-machines/virtual-machines-linux-mac-create-ssh-keys#create-and-configure-an-ssh-config-file
[how-to-get-pat]: https://www.visualstudio.com/en-us/docs/build/actions/agents/v2-linux#decide-which-user-youll-use
[pat-admin]: https://www.visualstudio.com/en-us/docs/build/actions/agents/v2-linux#confirm-the-user-has-permission
[extensions-gist]: https://gist.githubusercontent.com/gabrielweyer/4ec2cd4d8e2f03ae0f0b497aae926e2b/raw/18945d4ae754ed732be30194cc4831d50ae8e741/post-deployment-configuration.sh
[azure-portal]: https://portal.azure.com/
[troubleshooting-extensions]: https://docs.microsoft.com/en-us/azure/virtual-machines/virtual-machines-linux-extensions-customscript#troubleshooting