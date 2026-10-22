"""Strategy-driven broker import parsing package.

Keep package init side-effect free to avoid circular imports.
Import concrete modules directly, e.g.:
`from app.services.import_pipeline.parser_service import ExcelImportParserService`
"""

__all__: list[str] = []
