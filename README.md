# gce-ollama

Terraform + Taskfile to spin up a single-node [Ollama](https://ollama.com) inference server on a GCP SPOT instance with an NVIDIA RTX PRO 6000 GPU (96 GB GDDR7). Access is via IAP TCP tunnel — no public ingress.

## Stack

| Layer | Technology |
|---|---|
| Inference | Ollama (installed via startup script on GCE boot) |
| Compute | GCE SPOT instance — `g4-standard-48` (48 vCPU, 180 GB RAM, RTX PRO 6000 96 GB) |
| GPU | NVIDIA RTX PRO 6000 (integral to G4 machine type — no separate `guest_accelerator` block) |
| Model storage | tmpfs RAM disk — 150 GB at `/mnt/ramdisk`; synced to GCS after pull, restored from GCS on restart |
| Access | IAP TCP tunnel — `gcloud compute start-iap-tunnel`, no public IP |
| IaC | Terraform (google provider `~> 7.28`) |
| Automation | Taskfile (`task`) |
| Quality | pre-commit: terraform fmt/validate, shellcheck, yamllint, gitleaks |

## Prerequisites

- `gcloud` CLI authenticated (`gcloud auth application-default login`)
- `terraform` >= 1.5
- `task` ([Taskfile runner](https://taskfile.dev))
- `jq`, `curl`

## Quick Start

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set project_id to your GCP project
# Optionally adjust: region, zone, ollama_models

task up
```

`task up` will:
1. Run `terraform init` and `terraform apply`
2. Open an IAP tunnel in the background
3. Wait for the Ollama API to become ready
4. Run a verification test

## Accessing the Service

```bash
task models    # list loaded models (empty until pull/restore completes)
task logs      # tail startup log to watch progress
task verify    # run a generate test against localhost:11434
```

If you need to manually open a foreground tunnel (e.g. after a restart):

```bash
task tunnel:start
```

## Stop / Resume

```bash
task stop      # stops instance — halts compute billing, preserves infra and GCS cache
task start     # restarts instance — startup script restores model from GCS (~5 min)
```

## Tear Down

```bash
task destroy   # destroys all resources including GCS bucket (force_destroy = true)
```

## Key Files

| File | Purpose |
|---|---|
| `terraform.tf` | Terraform version and provider version constraints |
| `providers.tf` | Google provider configuration |
| `apis.tf` | GCP API enablement |
| `networking.tf` | VPC, subnet, IAP firewall rule |
| `storage.tf` | GCS model cache bucket |
| `iam.tf` | Service account, bucket IAM, project IAM bindings |
| `compute.tf` | GCE SPOT instance |
| `variables.tf` | All input variables with defaults |
| `outputs.tf` | Terraform outputs |
| `Taskfile.yml` | All automation tasks |
| `templates/startup.sh` | GCE startup script — mounts RAM disk, restores/syncs GCS, pulls models |
| `scripts/tunnel.sh` | IAP port-forward with retry logic |
| `scripts/verify.sh` | Health checks and generate test |
| `scripts/benchmark.sh` | Speed (t/s) and tool-call reliability benchmark |

## Available Tasks

Run `task --list` to see all tasks. Key ones:

| Task | Description |
|---|---|
| `task up` | Provision, tunnel, and verify |
| `task stop` / `task start` | Pause/resume compute billing |
| `task restart` | Stop then start instance (restores model from GCS) |
| `task destroy` | Tear down everything |
| `task delete` | Delete only compute instance + boot disk (preserves GCS cache and network) |
| `task tunnel` | Open IAP tunnel (foreground) |
| `task tunnel:start` / `task tunnel:stop` | Start/kill background IAP tunnel |
| `task status` | Show instance status and model pull progress |
| `task models` | List loaded models |
| `task pull` | Pull an Ollama model (`MODEL=<name>`) |
| `task verify` | Test the Ollama endpoint |
| `task bench` | Run benchmark (`--all`, `--model`, `--iterations`) |
| `task cache:push` | Manually sync RAM disk to GCS cache via SSH |
| `task cache:clear` | Delete all objects in the GCS model cache bucket |
| `task logs` | Stream startup logs |
| `task ssh` | SSH to instance via IAP |
| `task lint` | Run all linting checks |

## Gotchas

- **RAM disk is volatile.** `/mnt/ramdisk` is a tmpfs. Every stop/preemption wipes model data. The startup script restores from GCS cache (typically under 5 min) or re-pulls from the Ollama registry (10-30 min).
- **GCS bucket has `force_destroy = true`.** `task destroy` deletes the bucket and all cached model blobs.
- **SPOT preemption action is STOP, not DELETE.** Infrastructure and GCS cache are preserved; only the RAM disk content is lost.
- **GPU is integral to g4-standard-48.** No `guest_accelerator` block needed. `on_host_maintenance = "TERMINATE"` is required.
- **Boot disk requires Hyperdisk Balanced.** G4 machine types only support `hyperdisk-balanced`.

## License

Apache License 2.0 — see [LICENSE](LICENSE).
