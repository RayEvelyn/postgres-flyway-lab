# Local validation — 2026-10-03

Actual disposable Docker PostgreSQL/Flyway runtime: migrations V1-V3 applied, validate passed, second migrate reported no changes, history remains three versions and relational inserts succeeded inside rolled-back transaction. Editing applied migration SQL caused checksum rejection. Out-of-band ALTER TABLE passed ordinary validate, demonstrating history-validation limit; temporary change removed. Credential generated only for disposable local lab, ignored and never printed. Production credentials, upgrades with representative data and restore recovery not exercised.

Bash syntax, ShellCheck and Compose configuration pass. No existing infrastructure was changed. No Terraform apply, publication or Git push occurred.

## Separate platform paths and local bootstrap review (2026-10-03)

Both complete GitHub and GitLab source/runner/input/manual deployment paths are retained, with explicit router pages and no GitLab/KAS prerequisite in the GitHub path. GitLab protected file variables normalize into existing private runtime inputs; GitLab deployment rules require private projects and protected default refs. Checked actual glab variable/run/trigger/trace/repo-create help and official runner authentication environment inputs. Local actionlint, ShellCheck, Bash documentation syntax and YAML parsing passed. Terraform fmt/backend-disabled init/validate passed; existing hosted migration tests remain unchanged. No real Proxmox query, Terraform plan/apply, SSH bootstrap, runner registration, secret mint or Kubernetes deployment was performed in this review. Public hosted CI evidence is separate from these offline checks.
