CREATE TABLE deployments (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    project_id bigint NOT NULL REFERENCES projects(id),
    image_digest text NOT NULL,
    deployed_at timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX deployments_project_id_idx ON deployments (project_id);
