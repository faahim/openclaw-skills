# Example: Homelab NFS Setup

## Scenario
You have a NAS/server at 192.168.1.10 and want to share media, backups, and project files with 3 other machines on your network.

## Server Setup (192.168.1.10)

```bash
# Install NFS server
sudo bash scripts/nfs-manager.sh install-server

# Share directories
sudo bash scripts/nfs-manager.sh export /data/media 192.168.1.0/24
sudo bash scripts/nfs-manager.sh export /data/backups 192.168.1.0/24 ro
sudo bash scripts/nfs-manager.sh export /data/projects 192.168.1.0/24

# Open firewall
sudo bash scripts/nfs-manager.sh firewall-setup 192.168.1.0/24

# Verify
sudo bash scripts/nfs-manager.sh list-exports
sudo bash scripts/nfs-manager.sh health
```

## Client Setup (other machines)

```bash
# Install NFS client
sudo bash scripts/nfs-manager.sh install-client

# Mount shares
sudo bash scripts/nfs-manager.sh mount 192.168.1.10:/data/media /mnt/media
sudo bash scripts/nfs-manager.sh mount 192.168.1.10:/data/backups /mnt/backups
sudo bash scripts/nfs-manager.sh mount 192.168.1.10:/data/projects /mnt/projects

# Verify
bash scripts/nfs-manager.sh list-mounts
```

## Troubleshooting

```bash
# If mount fails, diagnose from client
bash scripts/nfs-manager.sh diagnose 192.168.1.10
```
