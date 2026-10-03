# Local validation — 2026-10-03

Actual disposable Docker PostgreSQL/Flyway runtime: migrations V1-V3 applied, validate passed, second migrate reported no changes, history remains three versions and relational inserts succeeded inside rolled-back transaction. Editing applied migration SQL caused checksum rejection. Out-of-band ALTER TABLE passed ordinary validate, demonstrating history-validation limit; temporary change removed. Credential generated only for disposable local lab, ignored and never printed. Production credentials, upgrades with representative data and restore recovery not exercised.

Bash syntax, ShellCheck and Compose configuration pass. No existing infrastructure was changed. No Terraform apply, publication or Git push occurred.
