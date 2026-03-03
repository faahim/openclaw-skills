# Example

```bash
sudo bash scripts/install.sh
sudo bash scripts/ufw-manager.sh backup --tag pre-prod
sudo bash scripts/ufw-manager.sh baseline --ssh-port 22
sudo bash scripts/ufw-manager.sh allow 80/tcp
sudo bash scripts/ufw-manager.sh allow 443/tcp
sudo bash scripts/ufw-manager.sh status
```
