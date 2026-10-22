"""Add uploaded_files table for Excel file storage tracking

Revision ID: 20260427_01
Revises: 20260424_02_benchmark_timescaledb_foundations
Create Date: 2026-04-27 10:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '20260427_01'
down_revision = '20260424_02'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'uploaded_files',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('import_job_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('original_filename', sa.String(length=255), nullable=False),
        sa.Column('stored_filename', sa.String(length=255), nullable=False),
        sa.Column('storage_path', sa.String(length=512), nullable=False),
        sa.Column('file_size_bytes', sa.Integer(), nullable=False),
        sa.Column('content_hash', sa.String(length=64), nullable=False, comment='SHA256 hash'),
        sa.Column('uploaded_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), server_default=sa.text('now()'), nullable=False),
        sa.ForeignKeyConstraint(['import_job_id'], ['import_jobs.id'], ondelete='SET NULL'),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('stored_filename')
    )
    op.create_index('ix_uploaded_files_content_hash', 'uploaded_files', ['content_hash'], unique=False)
    op.create_index('ix_uploaded_files_import_job', 'uploaded_files', ['import_job_id'], unique=False)
    op.create_index('ix_uploaded_files_user_created', 'uploaded_files', ['user_id', 'created_at'], unique=False)
    op.create_index('ix_uploaded_files_user_id', 'uploaded_files', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_uploaded_files_user_id', table_name='uploaded_files')
    op.drop_index('ix_uploaded_files_user_created', table_name='uploaded_files')
    op.drop_index('ix_uploaded_files_import_job', table_name='uploaded_files')
    op.drop_index('ix_uploaded_files_content_hash', table_name='uploaded_files')
    op.drop_table('uploaded_files')
