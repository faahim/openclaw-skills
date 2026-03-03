# Example Usage

## 1) Install + configure
```bash
bash scripts/install.sh
cp scripts/config-template.env ~/.config/zfs-snapshot-manager/config.env
nano ~/.config/zfs-snapshot-manager/config.env
```

## 2) Take snapshots
```bash
bash scripts/run.sh --action snapshot --class hourly
bash scripts/run.sh --action snapshot --class daily
```

## 3) Prune old snapshots
```bash
bash scripts/run.sh --action prune
```

## 4) Dry-run prune first
```bash
bash scripts/run.sh --action prune --dry-run
```
