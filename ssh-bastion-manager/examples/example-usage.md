# Example Usage

```bash
bash scripts/install.sh
sudo bash scripts/setup.sh --ssh-port 2222 --admin-user ubuntu --allow-cidr 203.0.113.0/24
sudo bash scripts/create-user.sh --user deploy --pubkey ./deploy.pub
bash scripts/audit.sh --expected-port 2222
```
