BEGIN;

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE note_embedding_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    note_kind VARCHAR(20) NOT NULL,
    medical_note_id UUID,
    handoff_note_id UUID,
    chunk_index INTEGER NOT NULL,
    content_excerpt TEXT NOT NULL,
    content_hash VARCHAR(64) NOT NULL,
    embedding_model VARCHAR(150) NOT NULL,
    embedding vector(384) NOT NULL,
    source_updated_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_note_embedding_chunks_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_note_embedding_chunks_medical UNIQUE (
        tenant_id, medical_note_id, chunk_index, embedding_model
    ),
    CONSTRAINT uq_note_embedding_chunks_handoff UNIQUE (
        tenant_id, handoff_note_id, chunk_index, embedding_model
    ),
    CONSTRAINT fk_note_embedding_chunks_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_note_embedding_chunks_medical FOREIGN KEY (tenant_id, medical_note_id)
        REFERENCES medical_notes (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_note_embedding_chunks_handoff FOREIGN KEY (tenant_id, handoff_note_id)
        REFERENCES handoff_notes (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT ck_note_embedding_chunks_kind CHECK (note_kind IN ('medical', 'handoff')),
    CONSTRAINT ck_note_embedding_chunks_source CHECK (
        (note_kind = 'medical' AND medical_note_id IS NOT NULL AND handoff_note_id IS NULL)
        OR
        (note_kind = 'handoff' AND handoff_note_id IS NOT NULL AND medical_note_id IS NULL)
    ),
    CONSTRAINT ck_note_embedding_chunks_index CHECK (chunk_index >= 0),
    CONSTRAINT ck_note_embedding_chunks_excerpt CHECK (btrim(content_excerpt) <> ''),
    CONSTRAINT ck_note_embedding_chunks_hash CHECK (content_hash ~ '^[0-9a-f]{64}$')
);

CREATE TABLE ai_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    job_type VARCHAR(20) NOT NULL,
    resource_id UUID NOT NULL,
    requested_by_user_id UUID NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'queued',
    priority INTEGER NOT NULL DEFAULT 100,
    attempts INTEGER NOT NULL DEFAULT 0,
    available_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    locked_at TIMESTAMPTZ,
    locked_by VARCHAR(150),
    error_code VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ,
    CONSTRAINT uq_ai_jobs_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_ai_jobs_active_resource UNIQUE NULLS NOT DISTINCT (
        tenant_id, job_type, resource_id, completed_at
    ),
    CONSTRAINT fk_ai_jobs_requester FOREIGN KEY (tenant_id, requested_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_ai_jobs_type CHECK (job_type IN ('index_note', 'summarize', 'answer')),
    CONSTRAINT ck_ai_jobs_status CHECK (status IN ('queued', 'running', 'completed', 'failed')),
    CONSTRAINT ck_ai_jobs_attempts CHECK (attempts BETWEEN 0 AND 2)
);

CREATE TABLE ai_worker_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    worker_id VARCHAR(150) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'healthy',
    embedding_model VARCHAR(150) NOT NULL,
    generation_model VARCHAR(150) NOT NULL,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ai_worker_heartbeats_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_ai_worker_heartbeats_worker UNIQUE (tenant_id, worker_id),
    CONSTRAINT ck_ai_worker_heartbeats_status CHECK (
        status IN ('healthy', 'degraded', 'stopping')
    )
);

CREATE TABLE note_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    note_kind VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'queued',
    content JSONB,
    source_hash VARCHAR(64) NOT NULL,
    model_id VARCHAR(150),
    model_hash VARCHAR(64),
    prompt_version VARCHAR(50) NOT NULL,
    requested_by_user_id UUID NOT NULL,
    generated_at TIMESTAMPTZ,
    stale_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_note_summaries_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_note_summaries_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_note_summaries_requester FOREIGN KEY (tenant_id, requested_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_note_summaries_kind CHECK (note_kind IN ('medical', 'handoff')),
    CONSTRAINT ck_note_summaries_status CHECK (
        status IN ('queued', 'running', 'completed', 'failed', 'stale')
    ),
    CONSTRAINT ck_note_summaries_content CHECK (
        content IS NULL OR jsonb_typeof(content) = 'object'
    ),
    CONSTRAINT ck_note_summaries_source_hash CHECK (source_hash ~ '^[0-9a-f]{64}$')
);

CREATE TABLE note_summary_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    summary_id UUID NOT NULL,
    medical_note_id UUID,
    handoff_note_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_note_summary_sources_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_note_summary_sources_medical UNIQUE (
        tenant_id, summary_id, medical_note_id
    ),
    CONSTRAINT uq_note_summary_sources_handoff UNIQUE (
        tenant_id, summary_id, handoff_note_id
    ),
    CONSTRAINT fk_note_summary_sources_summary FOREIGN KEY (tenant_id, summary_id)
        REFERENCES note_summaries (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_note_summary_sources_medical FOREIGN KEY (tenant_id, medical_note_id)
        REFERENCES medical_notes (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_note_summary_sources_handoff FOREIGN KEY (tenant_id, handoff_note_id)
        REFERENCES handoff_notes (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT ck_note_summary_sources_source CHECK (
        num_nonnulls(medical_note_id, handoff_note_id) = 1
    )
);

CREATE TABLE ai_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    patient_id UUID NOT NULL,
    note_kind VARCHAR(20) NOT NULL,
    requested_by_user_id UUID NOT NULL,
    question TEXT NOT NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'queued',
    answer TEXT,
    model_id VARCHAR(150),
    model_hash VARCHAR(64),
    prompt_version VARCHAR(50) NOT NULL,
    feedback_rating VARCHAR(20),
    feedback_reason VARCHAR(30),
    generated_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '90 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ai_interactions_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_ai_interactions_patient FOREIGN KEY (tenant_id, patient_id)
        REFERENCES patients (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_ai_interactions_requester FOREIGN KEY (tenant_id, requested_by_user_id)
        REFERENCES users (tenant_id, id) ON DELETE RESTRICT,
    CONSTRAINT ck_ai_interactions_kind CHECK (note_kind IN ('medical', 'handoff')),
    CONSTRAINT ck_ai_interactions_question CHECK (
        btrim(question) <> '' AND char_length(question) <= 500
    ),
    CONSTRAINT ck_ai_interactions_status CHECK (
        status IN ('queued', 'running', 'supported', 'insufficient_information', 'failed')
    ),
    CONSTRAINT ck_ai_interactions_feedback_rating CHECK (
        feedback_rating IS NULL OR feedback_rating IN ('helpful', 'not_helpful')
    ),
    CONSTRAINT ck_ai_interactions_feedback_reason CHECK (
        feedback_reason IS NULL
        OR feedback_reason IN ('incorrect', 'incomplete', 'irrelevant', 'missing_source')
    )
);

CREATE TABLE ai_interaction_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    interaction_id UUID NOT NULL,
    embedding_chunk_id UUID NOT NULL,
    rank INTEGER NOT NULL,
    score DOUBLE PRECISION NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_ai_interaction_sources_tenant_id_id UNIQUE (tenant_id, id),
    CONSTRAINT uq_ai_interaction_sources_assignment UNIQUE (
        tenant_id, interaction_id, embedding_chunk_id
    ),
    CONSTRAINT fk_ai_interaction_sources_interaction FOREIGN KEY (tenant_id, interaction_id)
        REFERENCES ai_interactions (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT fk_ai_interaction_sources_chunk FOREIGN KEY (tenant_id, embedding_chunk_id)
        REFERENCES note_embedding_chunks (tenant_id, id) ON DELETE CASCADE,
    CONSTRAINT ck_ai_interaction_sources_rank CHECK (rank > 0),
    CONSTRAINT ck_ai_interaction_sources_score CHECK (score BETWEEN 0 AND 1)
);

CREATE INDEX idx_note_embedding_chunks_lookup
    ON note_embedding_chunks (tenant_id, patient_id, note_kind, embedding_model);
CREATE INDEX idx_ai_jobs_claim
    ON ai_jobs (status, priority, available_at, created_at)
    WHERE status = 'queued';
CREATE INDEX idx_ai_worker_heartbeats_seen
    ON ai_worker_heartbeats (tenant_id, last_seen_at DESC);
CREATE INDEX idx_note_summaries_latest
    ON note_summaries (tenant_id, patient_id, note_kind, created_at DESC);
CREATE INDEX idx_ai_interactions_history
    ON ai_interactions (tenant_id, patient_id, note_kind, created_at DESC);
CREATE INDEX idx_ai_interactions_expiration
    ON ai_interactions (expires_at);

ALTER TABLE note_embedding_chunks ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_worker_heartbeats ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_summary_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_interaction_sources ENABLE ROW LEVEL SECURITY;

CREATE POLICY read_note_embedding_chunks ON note_embedding_chunks FOR SELECT
    USING (
        tenant_id = current_app_tenant_id()
        AND (
            note_kind = 'handoff'
            OR EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
                WHERE ur.tenant_id = note_embedding_chunks.tenant_id
                  AND ur.user_id = current_app_user_id()
                  AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
                  AND r.deleted_at IS NULL
            )
        )
    );
CREATE POLICY write_note_embedding_chunks ON note_embedding_chunks
    FOR ALL
    USING (
        tenant_id = current_app_tenant_id()
        AND (
            note_kind = 'handoff'
            OR EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
                WHERE ur.tenant_id = note_embedding_chunks.tenant_id
                  AND ur.user_id = current_app_user_id()
                  AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
                  AND r.deleted_at IS NULL
            )
        )
    )
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND (
            note_kind = 'handoff'
            OR EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
                WHERE ur.tenant_id = note_embedding_chunks.tenant_id
                  AND ur.user_id = current_app_user_id()
                  AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
                  AND r.deleted_at IS NULL
            )
        )
    );
CREATE POLICY tenant_isolation_ai_jobs ON ai_jobs
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY tenant_isolation_ai_worker_heartbeats ON ai_worker_heartbeats
    FOR ALL USING (tenant_id = current_app_tenant_id())
    WITH CHECK (tenant_id = current_app_tenant_id());
CREATE POLICY access_note_summaries ON note_summaries
    FOR ALL
    USING (
        tenant_id = current_app_tenant_id()
        AND (
            note_kind = 'handoff'
            OR EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
                WHERE ur.tenant_id = note_summaries.tenant_id
                  AND ur.user_id = current_app_user_id()
                  AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
                  AND r.deleted_at IS NULL
            )
        )
    )
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND (
            note_kind = 'handoff'
            OR EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
                WHERE ur.tenant_id = note_summaries.tenant_id
                  AND ur.user_id = current_app_user_id()
                  AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
                  AND r.deleted_at IS NULL
            )
        )
    );
CREATE POLICY access_note_summary_sources ON note_summary_sources
    FOR ALL
    USING (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM note_summaries summary
            WHERE summary.tenant_id = note_summary_sources.tenant_id
              AND summary.id = note_summary_sources.summary_id
        )
    )
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM note_summaries summary
            WHERE summary.tenant_id = note_summary_sources.tenant_id
              AND summary.id = note_summary_sources.summary_id
        )
    );
CREATE POLICY access_ai_interactions ON ai_interactions
    FOR ALL
    USING (
        tenant_id = current_app_tenant_id()
        AND requested_by_user_id = current_app_user_id()
        AND (
            note_kind = 'handoff'
            OR EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
                WHERE ur.tenant_id = ai_interactions.tenant_id
                  AND ur.user_id = current_app_user_id()
                  AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
                  AND r.deleted_at IS NULL
            )
        )
    )
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND requested_by_user_id = current_app_user_id()
        AND (
            note_kind = 'handoff'
            OR EXISTS (
                SELECT 1
                FROM user_roles ur
                JOIN roles r ON r.tenant_id = ur.tenant_id AND r.id = ur.role_id
                WHERE ur.tenant_id = ai_interactions.tenant_id
                  AND ur.user_id = current_app_user_id()
                  AND r.name IN ('admin', 'direccion', 'coordinador', 'medico', 'terapeuta')
                  AND r.deleted_at IS NULL
            )
        )
    );
CREATE POLICY access_ai_interaction_sources ON ai_interaction_sources
    FOR ALL
    USING (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM ai_interactions interaction
            WHERE interaction.tenant_id = ai_interaction_sources.tenant_id
              AND interaction.id = ai_interaction_sources.interaction_id
        )
    )
    WITH CHECK (
        tenant_id = current_app_tenant_id()
        AND EXISTS (
            SELECT 1
            FROM ai_interactions interaction
            WHERE interaction.tenant_id = ai_interaction_sources.tenant_id
              AND interaction.id = ai_interaction_sources.interaction_id
        )
    );

CREATE TRIGGER trigger_update_note_embedding_chunks_timestamp
    BEFORE UPDATE ON note_embedding_chunks FOR EACH ROW
    EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_ai_jobs_timestamp
    BEFORE UPDATE ON ai_jobs FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_note_summaries_timestamp
    BEFORE UPDATE ON note_summaries FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();
CREATE TRIGGER trigger_update_ai_interactions_timestamp
    BEFORE UPDATE ON ai_interactions FOR EACH ROW EXECUTE FUNCTION update_timestamp_column();

CREATE OR REPLACE FUNCTION enqueue_note_ai_refresh()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
    source_row JSONB := COALESCE(to_jsonb(NEW), to_jsonb(OLD));
    source_id UUID := (source_row->>'id')::UUID;
    source_tenant_id UUID := (source_row->>'tenant_id')::UUID;
    source_patient_id UUID := (source_row->>'patient_id')::UUID;
    source_kind VARCHAR(20) := CASE
        WHEN TG_TABLE_NAME = 'medical_notes' THEN 'medical'
        ELSE 'handoff'
    END;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM ai_jobs
        WHERE tenant_id = source_tenant_id
          AND job_type = 'index_note'
          AND resource_id = source_id
          AND status IN ('queued', 'running')
    ) THEN
        INSERT INTO ai_jobs (
            tenant_id, job_type, resource_id, requested_by_user_id, status, priority
        )
        VALUES (
            source_tenant_id, 'index_note', source_id, current_app_user_id(), 'queued', 10
        );
    END IF;

    UPDATE note_summaries
    SET status = 'stale',
        stale_at = CURRENT_TIMESTAMP
    WHERE tenant_id = source_tenant_id
      AND patient_id = source_patient_id
      AND note_kind = source_kind
      AND status = 'completed';

    RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE ALL ON FUNCTION enqueue_note_ai_refresh() FROM PUBLIC;

CREATE TRIGGER enqueue_medical_note_ai_refresh
    AFTER INSERT OR UPDATE OF content, deleted_at OR DELETE
    ON medical_notes
    FOR EACH ROW EXECUTE FUNCTION enqueue_note_ai_refresh();
CREATE TRIGGER enqueue_handoff_note_ai_refresh
    AFTER INSERT OR UPDATE OF title, content, priority, status, deleted_at OR DELETE
    ON handoff_notes
    FOR EACH ROW EXECUTE FUNCTION enqueue_note_ai_refresh();

COMMIT;
