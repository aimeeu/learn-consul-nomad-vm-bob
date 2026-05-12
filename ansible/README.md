# Ansible Playbook for HashiStack Setup

This directory contains Ansible playbooks for setting up the HashiStack (Consul, Nomad, Vault) infrastructure, converted from the original `setup.sh` bash script.

## Files

- **`setup-hashistack.yml`** - Main playbook that installs and configures HashiStack components
- **`ansible.cfg`** - Ansible configuration file
- **`inventory.ini.example`** - Example inventory file template

## Prerequisites

- Ansible >= 2.9 installed on your control machine
- SSH access to target hosts
- Target hosts running Ubuntu/Debian
- Sudo privileges on target hosts

## Quick Start

### 1. Create Inventory File

Copy the example inventory and update with your host IPs:

```bash
cp inventory.ini.example inventory.ini
```

Edit `inventory.ini` with your actual host information:

```ini
[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/your-key.pem
ansible_python_interpreter=/usr/bin/python3

[servers]
server-1 ansible_host=YOUR_SERVER_IP_1
server-2 ansible_host=YOUR_SERVER_IP_2
server-3 ansible_host=YOUR_SERVER_IP_3

[clients]
client-1 ansible_host=YOUR_CLIENT_IP_1
client-2 ansible_host=YOUR_CLIENT_IP_2
client-3 ansible_host=YOUR_CLIENT_IP_3

[public_clients]
public-client-1 ansible_host=YOUR_PUBLIC_CLIENT_IP
```

### 2. Test Connectivity

```bash
ansible all -m ping
```

### 3. Run the Playbook

Install HashiStack on all hosts:

```bash
ansible-playbook setup-hashistack.yml
```

Run on specific host groups:

```bash
# Only servers
ansible-playbook setup-hashistack.yml --limit servers

# Only clients
ansible-playbook setup-hashistack.yml --limit clients
```

### 4. Verify Installation

Check installed versions:

```bash
ansible all -m shell -a "consul version"
ansible all -m shell -a "nomad version"
ansible all -m shell -a "vault version"
```

## What Gets Installed

### System Packages
- `unzip`, `tree`, `redis-tools`, `jq`, `curl`, `tmux`, `nano`
- Docker CE
- OpenJDK 8

### HashiStack Components
- **Consul** v1.22.5
- **Nomad** v2.0.1
- **Vault** v1.21.3
- **Consul Template** v0.41.4

### Configuration
- Consul Template directories created at:
  - `/etc/consul-template.d` (config)
  - `/opt/consul-template` (binary)
- UFW firewall disabled
- Docker service enabled and started
- JAVA_HOME environment variable set

## Customization

### Change HashiStack Versions

Edit the `vars` section in `setup-hashistack.yml`:

```yaml
vars:
  consul_version: "1.22.5"
  vault_version: "1.21.3"
  nomad_version: "2.0.1"
  consul_template_version: "0.41.4"
```

### Change Cloud Environment

Set the `cloud_env` variable for your cloud provider:

```yaml
vars:
  cloud_env: "aws"  # Options: aws, gce, azure
```

### Run with Extra Variables

Override variables at runtime:

```bash
ansible-playbook setup-hashistack.yml \
  -e "consul_version=1.23.0" \
  -e "nomad_version=2.1.0"
```

## Playbook Structure

The playbook is organized into logical sections:

1. **System Prerequisites** - Install base packages and repositories
2. **Firewall Configuration** - Disable UFW
3. **Consul Template Directories** - Create required directories
4. **Docker Installation** - Install and configure Docker
5. **Java Installation** - Install OpenJDK 8
6. **HashiCorp Repository Setup** - Add HashiCorp APT repository
7. **HashiStack Installation** - Install Consul, Nomad, Vault, Consul Template
8. **Verification** - Verify installations and display versions

## Troubleshooting

### SSH Connection Issues

If you encounter SSH connection problems:

```bash
# Test SSH manually
ssh -i ~/.ssh/your-key.pem ubuntu@YOUR_HOST_IP

# Use verbose mode
ansible-playbook setup-hashistack.yml -vvv
```

### Permission Denied

Ensure your SSH key has correct permissions:

```bash
chmod 600 ~/.ssh/your-key.pem
```

### Package Installation Failures

If package installation fails, you can:

1. Check if the specified versions are available:
   ```bash
   ansible all -m shell -a "apt-cache madison consul"
   ```

2. Run with check mode first:
   ```bash
   ansible-playbook setup-hashistack.yml --check
   ```

### Docker Installation Issues

If Docker installation fails on Debian-based systems, the playbook uses the Debian repository. For Ubuntu-specific issues, you may need to adjust the repository URL in the playbook.

## Comparison with setup.sh

This Ansible playbook provides several advantages over the original bash script:

- ✅ **Idempotent** - Safe to run multiple times
- ✅ **Parallel Execution** - Runs on multiple hosts simultaneously
- ✅ **Error Handling** - Better error reporting and recovery
- ✅ **Modular** - Easy to customize and extend
- ✅ **Verification** - Built-in verification steps
- ✅ **Logging** - Detailed execution logs

## Integration with Terraform

This playbook can be integrated with Terraform using the `local-exec` provisioner or by generating the inventory file from Terraform outputs.

Example Terraform integration:

```hcl
resource "null_resource" "ansible_provisioning" {
  depends_on = [aws_instance.servers, aws_instance.clients]
  
  provisioner "local-exec" {
    command = "ansible-playbook -i inventory.ini setup-hashistack.yml"
    working_dir = "${path.module}/../ansible"
  }
}
```

## Next Steps

After running this playbook:

1. Configure Consul servers and clients using the configuration files in `shared/conf/`
2. Set up Nomad servers and clients
3. Bootstrap Consul ACLs
4. Deploy the HashiCups application using the job specifications in `shared/jobs/`

## License

This playbook is part of the learn-consul-nomad-vm-bob project.