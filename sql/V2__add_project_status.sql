-- Expand first: existing applications can keep working with the old columns.
ALTER TABLE projects ADD COLUMN status text NOT NULL DEFAULT 'planned';
ALTER TABLE projects ADD CONSTRAINT projects_status_check
    CHECK (status IN ('planned', 'active', 'archived'));
CREATE INDEX projects_status_idx ON projects (status);
