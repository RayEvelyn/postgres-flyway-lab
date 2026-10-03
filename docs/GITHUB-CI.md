# GitHub source and Actions execution

This path has no GitLab or KAS dependency.

## Clone and run real CI deployments

```bash
git clone https://github.com/RayEvelyn/postgres-flyway-lab.git
cd postgres-flyway-lab
```

The public repository runs `.github/workflows/validate.yml` on hosted runners. It actually starts a disposable PostgreSQL database, applies the SQL migrations, validates their history, and verifies that reapplying is a no-op. Its temporary database is destroyed after this isolated test. The deployment workflow never runs from this public example. Keep a private deployment copy so outside contributors cannot execute code on a runner inside your home network.

Create your private copy using the GitHub CLI, replacing `YOUR_ACCOUNT` and the chosen repository name:

```bash
gh repo create YOUR_ACCOUNT/postgres-home --private
# Keep upstream as a reference; publish only your own sanitized inputs.
git remote rename origin upstream
git remote add origin https://github.com/YOUR_ACCOUNT/postgres-home.git
git push -u origin main
export DEPLOY_REPO=YOUR_ACCOUNT/postgres-home
```

Register one permanent Linux self-hosted runner, labelled `homelab`, in that private repository using GitHub's runner registration API/CLI. It needs access to the Proxmox API and guest management address, Terraform 1.16.4, OpenSSH, Python 3 and `flock`. Do not attach this runner to public pull-request jobs. The workflow's `homelab` environment is an additional boundary; configure reviewers if your account supports them. The helper requires an existing protected state directory outside the checkout and temporary directories:

```bash
# On the dedicated runner, replace runner-user with its actual Linux user.
sudo install -d -m 0700 -o runner-user -g runner-user /var/lib/homelab-terraform
# On your authenticated workstation:
gh variable set TF_STATE_ROOT --repo "$DEPLOY_REPO" --body /var/lib/homelab-terraform
cp terraform/ci-inputs.example.json ci-inputs.json
# Edit ci-inputs.json to YOUR unused VM ID, template, storage, bridge and IP.
gh variable set HOMELAB_TFVARS_JSON --repo "$DEPLOY_REPO" --body "$(cat ci-inputs.json)"
gh variable set PROXMOX_VE_ENDPOINT --repo "$DEPLOY_REPO" --body https://proxmox.example.test:8006/
gh secret set PROXMOX_VE_API_TOKEN --repo "$DEPLOY_REPO" # interactive, hidden input
# These files belong to you; never put private keys in the cloned repository.
gh secret set SSH_PRIVATE_KEY --repo "$DEPLOY_REPO" < /secure/path/lab-key
gh secret set PROXMOX_CA_PEM --repo "$DEPLOY_REPO" < /secure/path/proxmox-ca.pem
gh variable set DEPLOY_ENABLED --repo "$DEPLOY_REPO" --body true
gh workflow run deploy.yml --repo "$DEPLOY_REPO" -f action=plan
# Inspect the plan's changes in the workflow logs before authorizing creation.
gh workflow run deploy.yml --repo "$DEPLOY_REPO" -f action=provision
```

Plan does not apply. Provision creates the VM and stops before SSH; a new guest's host keys must be verified independently before its first deployment. Use the trusted Proxmox console or `qm guest exec VMID -- ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` on the node to obtain the fingerprint, compare the candidate returned by `ssh-keyscan`, then save the matching known-host line privately. `ssh-keyscan` alone does not authenticate a guest.

```bash
gh secret set SSH_KNOWN_HOSTS --repo "$DEPLOY_REPO" < /secure/path/verified-known-hosts
gh workflow run deploy.yml --repo "$DEPLOY_REPO" -f action=deploy
```

Deploy creates a fresh saved plan, applies that plan, waits for authenticated SSH and cloud-init, then copies only the public Compose and SQL files and runs `scripts/bootstrap-guest.sh`. That script installs Docker on the dedicated Ubuntu guest, preserves the guest's existing database password and volume, refuses edits/removal of existing SQL migrations, and runs Flyway migrate followed by validate. It never runs `clean` or removes database volumes. This is an actual executable deployment path, not a placeholder command; its Proxmox execution requires your credentials and network.

Persistent state is stored as `/var/lib/homelab-terraform/github-REPOSITORY_ID/terraform.tfstate`, with restrictive directory permissions and both backend locking and a host `flock` across the entire operation. Back it up privately. This local backend has no high availability: never use an ephemeral runner or two independent state directories to manage the same VM. Moving from local CLI to CI,  requires adopting the existing state at the new backend path before planning; inspect a refresh-only plan and the next ordinary plan for unexpected creates. Do not copy a state into public Git or artifacts. VM `prevent_destroy` deliberately stops replacement/deletion until an explicit reviewed change removes the guard.


## Register the GitHub execution runner with CLI tools

Install a reviewed official Actions runner distribution on the dedicated Linux host first and run as its dedicated account. Keep that directory private; preserve an existing registration instead of replacing it. The current runner accepts `ACTIONS_RUNNER_INPUT_TOKEN`, avoiding token arguments/history. This setup belongs only to the private GitHub repository:

```bash
# On the dedicated host, with gh authenticated for your private repository:
umask 077
cd /path/to/reviewed/actions-runner
registration_file=$(mktemp)
gh api --method POST "repos/$DEPLOY_REPO/actions/runners/registration-token" > "$registration_file"
export ACTIONS_RUNNER_INPUT_TOKEN
ACTIONS_RUNNER_INPUT_TOKEN=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["token"])' "$registration_file")
./config.sh --unattended --url "https://github.com/$DEPLOY_REPO" --labels homelab --name homelab-fixed --work _work
unset ACTIONS_RUNNER_INPUT_TOKEN
rm -f -- "$registration_file"
./run.sh
```

The final command runs the registered runner in the foreground; configure its service with the official `svc.sh` tool when you deliberately want persistence. Do not run it as root or accept public jobs. The CLI example creates a runner registration when you execute it; validation of this repository does not register anything. [Official runner input implementation](https://github.com/actions/runner/blob/main/src/Runner.Listener/CommandSettings.cs).
