# PostgreSQL DDL and Flyway: make database changes reviewable

Start with [GitOps, the bootstrap order, and why the repos are separate](docs/START-HERE.md).

A small hands-on lab for learning why SQL schema changes belong in version control, how Flyway applies them in order, and where its guarantees stop.

## Choose one source and execution platform

| Choice | Private source of truth | Deployment execution | Cluster access |
|---|---|---|---|
| [GitHub path](docs/GITHUB-CI.md) | Your private GitHub repository | GitHub Actions and its dedicated runner | Direct scoped kubeconfig for cluster jobs; no GitLab/KAS prerequisite |
| [GitLab path](docs/GITLAB-CI.md) | Your private GitLab project | GitLab CI and its dedicated runner | Optional GitLab agent/KAS for cluster jobs |

The canonical public GitHub repository distributes examples and runs unprivileged validation. Choose one private source and runner platform for each real target; do not combine a GitHub source checkout with instructions for a GitLab runner, or let both pipelines manage the same resource. GitLab-first bootstrap applies only when you select self-managed GitLab. GitHub can bootstrap the GitLab VM as a service without depending on that service's CI. KAS is a GitLab integration, not a universal prerequisite for Kubernetes or GitOps. Flux or another chosen reconciler can use either supported Git source.


## Why this matters before your application grows

A database schema is part of your application contract. If one developer adds a column by hand and another environment never receives it, identical application code can behave differently. Versioned migrations make the change explicit, reviewable and repeatable.

**DDL** means Data Definition Language: `CREATE TABLE`, `ALTER TABLE`, indexes, constraints and other structure changes. **DML** changes rows: `INSERT`, `UPDATE`, `DELETE`. Both can appear in migrations, but data changes need special care around volume, privacy, locking and recovery.

Flyway records applied migrations in `flyway_schema_history`. A numbered migration is applied once, in version order, and its checksum is stored. Later validation catches changed or missing applied migration files. This gives you an audit trail of migration execution; it does not replace database backups or review SQL for you.

Importantly, ordinary `flyway validate` checks migration history and checksums. It is **not a full live-schema drift comparison**: someone manually adding a column can go undetected by history validation. Detect out-of-band changes using appropriate schema comparison, permissions and review practices as well.

## Start with GitOps and clear ownership

Prepare networking first, then choose the source and execution platform above. For self-managed GitLab, bootstrap GitLab locally before importing projects; GitHub uses its own private repository and Actions runner directly. Keep credentials outside either source platform.

GitOps declares desired state in Git and reconciles real systems to it. Database migrations are ordered transitions with data consequences; they are not a resource you can safely delete and recreate whenever Git changes. Review them separately and use an explicit migration gate alongside application delivery.

| Repo | Responsibility | Why separate it |
| --- | --- | --- |
| `app` | Application source, tests and image builds | Frequent code changes do not need database-owner access |
| `terraform` | Hosts, networking, storage and cloud/provider resources | Infrastructure plans can replace or destroy persistent resources |
| `manifests` | Kubernetes workloads, Services, policies and Helm values | Application rollout lifecycle differs from VM lifecycle |
| `flyway` | Ordered SQL migrations and migration validation | Schema changes need sequencing, locking and recovery decisions |

One repo can contain separate directories while learning. Separate repos become useful when credentials, reviewers and release timing differ. The ownership boundary matters more than the number of repositories. Do not let Terraform and Flyway both manage the same database table.

For the optional GitLab Kubernetes path, KAS is GitLab's agent server. A cluster-side agent opens an outbound connection so authorized CI jobs can access Kubernetes without exposing its API publicly. Scope `ci_access` and Kubernetes RBAC. KAS does not itself run SQL migrations, reconcile workloads or remove the need for a migration credential. Never commit agent tokens or admin kubeconfigs.

## What this lab creates

- PostgreSQL 17.6 on a private Compose network with a persistent named volume and no published database port.
- Flyway 13.9.0, version- and digest-pinned.
- Three migrations: a projects table, a status column/constraint/index, and a deployments table with a foreign key.
- A randomly generated **local lab** password in ignored `secrets/db_password`, mode600, mounted as a Compose secret. No owner's credentials are read.
- `clean` disabled and a wrapper permitting only `info`, `migrate` and `validate`.

Flyway's current image is amd64-only here. The Compose file explicitly chooses amd64 so Docker Desktop on Apple Silicon can emulate it. A Linux amd64 lab host avoids emulation overhead.

The lab database user is intentionally an owner/superuser created by the PostgreSQL image for a disposable database. Production must separate the application runtime role from a migration role with the specific privileges it needs. Do not copy this lab account design into production.

## Run it locally

Install Docker Engine/Compose v2 or Docker Desktop, plus OpenSSL. Then:

```bash
./scripts/setup.sh
docker compose config --quiet
docker compose up -d database
./scripts/flyway.sh info
./scripts/flyway.sh migrate
./scripts/flyway.sh validate
./scripts/verify.sh
```

The password is generated once and preserved on reruns. It is not printed or passed as a command argument. The wrapper reads the secret inside the container. Docker administrators can still inspect container secrets and process environments; this protects against accidental Git/log leakage, not a compromised host.

See the execution record yourself:

```bash
docker compose exec database psql -U migration_owner -d homelab -c \
  'SELECT installed_rank, version, description, success FROM flyway_schema_history ORDER BY installed_rank;'
docker compose exec database psql -U migration_owner -d homelab -c '\d projects'
```

Running `migrate` again should report that the schema is current, rather than recreate tables. Verification also performs related inserts inside a transaction and rolls them back, leaving no sample rows.

## Write your next migration

Create `sql/V4__add_project_description.sql` in a branch:

```sql
ALTER TABLE projects ADD COLUMN description text;
```

The double underscore separates version from description. Versions must be unique; resolve collisions before merging. SQL names should tell a reviewer what will change.

Review the statement and test it on a fresh disposable database and a database representing the previous schema. Only then promote that same migration through staging and production. Once applied to a persistent environment, do not rewrite V1, V2 or V3; add a new migration to correct the result.

This lab intentionally uses ordinary `CREATE TABLE` rather than hiding unexpected state with `IF NOT EXISTS`. A migration should fail clearly if the expected starting schema is wrong. Idempotence of the whole migration workflow comes from Flyway's execution history, not from silently ignoring every conflict.

## Safe evolution: expand, migrate, contract

Suppose a column needs a new shape. First add the new structure while old application versions keep working. Next deploy code that can handle both forms and backfill existing rows in bounded batches. Verify the new path. Remove the old structure only in a later reviewed release after old code no longer depends on it.

This avoids coupling a breaking database operation to a rolling application deployment. Even an additive `ALTER TABLE` can take locks. Review table sizes, lock acquisition, statement/lock timeouts and transaction duration. Test with realistic data before production.

Most PostgreSQL DDL is transactional, and Flyway normally runs transactional PostgreSQL migrations within transactions. Some operations, such as `CREATE INDEX CONCURRENTLY`, cannot run inside a transaction block; configure a dedicated migration appropriately and plan recovery for partial effects. Do not assume every database engine has PostgreSQL's transactional behavior.

## CI/CD: validate, test, then promote

A useful pipeline is:

1. Run syntax/lint checks and start a fresh disposable PostgreSQL database.
2. Apply all migrations and run `validate` plus application integration tests.
3. Test upgrades from the previous released schema using representative sanitized data.
4. Require review and protected environment approval for production migration execution.
5. Run migrations with a scoped credential, then deploy compatible application code and verify health.

Keep database passwords in protected CI secrets or retrieve short-lived credentials through Vault where configured. Do not pass passwords in command arguments, echo them, use shell tracing around secrets, or publish dumps/state as CI artifacts. A deploy runner should not receive an administrator credential merely because it can build an image.

If CI uses KAS to create a Kubernetes migration Job, grant only the intended namespace operations. Decide who owns that Job manifest and who owns its SQL files; the migration credential still needs a protected delivery path.

## Proxmox and bare metal

This repo includes Terraform to provision a dedicated Ubuntu 24.04 VM and deployment scripts to install Docker and run this project. Bare-metal users run it on a dedicated Linux lab host instead. No OS disk formatting or Proxmox apply runs automatically.

Keep PostgreSQL storage backed up outside the host. A VM snapshot is not automatically a tested application-consistent database backup. Keep configuration, migration history and a recoverable database backup together in your recovery plan.

## Failures, repair and backups

- **Checksum mismatch:** restore the original applied migration file and add a new migration. Do not reflexively run `repair` to bless an accidental edit.
- **SQL error:** read the failing statement and determine what was committed. Transactional and nontransactional failures need different recovery. Preserve the evidence, fix the intended next change, and retest.
- **Existing database:** decide on a deliberate audited baseline. Do not enable automatic baselining merely to make an unexpected schema pass.
- **Manual drift:** history validation may pass despite extra columns or indexes. Restrict write privileges and compare actual schema where required.
- **Lost local password file:** the database volume still has the original password. Restoring the file from your private backup is different from generating a new file; a new file does not change an initialized database's password.

`repair` changes Flyway metadata; it does not undo arbitrary SQL or prove that the schema is correct. `clean` destroys managed objects and is disabled here. Flyway Community does not give a universal automatic rollback button. Recovery may mean a forward corrective migration or a tested restore, with application compatibility considered.

Create a private backup without printing a password:

```bash
umask 077
mkdir -p backups
docker compose exec -T database pg_dump -U migration_owner -d homelab -Fc > backups/homelab.dump
```

Backups may contain sensitive data. Keep them outside public Git, protect them, and practice restoring into a **separate disposable database** before relying on them. `backups/` is ignored.

## Cleanup

```bash
docker compose down
```

This stops the lab and retains its named database volume. Only for a disposable database you explicitly intend to delete, use `docker compose down --volumes` after backing up anything needed. There is no automated destroy helper.

## Official references and verification

- [Flyway versioned migrations](https://documentation.red-gate.com/flyway/flyway-concepts/migrations/versioned-migrations)
- [What validate actually checks](https://documentation.red-gate.com/flyway/reference/commands/validate)
- [PostgreSQL transactional behavior](https://www.postgresql.org/docs/17/tutorial-transactions.html)
- [PostgreSQL concurrent index caveats](https://www.postgresql.org/docs/17/sql-createindex.html)
- [GitLab Kubernetes Agent documentation](https://docs.gitlab.com/user/clusters/agent/)

See `VALIDATION.md` for actual local results and remaining limits. A successful disposable migration test is not permission to execute these examples against a production database.

## Deployment instructions

Use the selected [GitHub path](docs/GITHUB-CI.md) or [GitLab path](docs/GITLAB-CI.md) for a complete source-to-runner deployment. Local Compose and workstation Terraform remain separate learning/bootstrap options.
