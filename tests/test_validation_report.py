"""Tests du rapport de validation et de sa commande CLI."""

from datetime import UTC, datetime
from pathlib import Path

import pytest
from click.testing import CliRunner

from cgp.cli import main
from cgp.repo import RepoRootNotFoundError, find_repo_root
from cgp.validation_report import (
    DocsMarkerCollector,
    PendingItem,
    PromptCollector,
    collect_pending,
    parse_front_matter,
    render_report,
    summarize_line,
    write_report,
)


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    (tmp_path / "CLAUDE.md").write_text("# racine\n", encoding="utf-8")
    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "05-safety.md").write_text(
        "# Titre\n\n- Le service est conçu comme un cabinet. **[À VALIDER]**\n\nRien ici.\n",
        encoding="utf-8",
    )
    (docs / "sub").mkdir()
    (docs / "sub" / "x.md").write_text("| seuil [À VALIDER] | 5 |\n", encoding="utf-8")
    prompts = tmp_path / "packages" / "agents" / "prompts"
    (prompts / "estate").mkdir(parents=True)
    (prompts / "estate" / "v1.md").write_text(
        "---\nreviewed_by: null\nversion: 1\n---\nCorps du prompt.\n", encoding="utf-8"
    )
    (prompts / "planner").mkdir()
    (prompts / "planner" / "v2.md").write_text(
        "---\nreviewed_by: Jeanne\n---\nCorps.\n", encoding="utf-8"
    )
    return tmp_path


def test_docs_collector_reports_each_marked_line(repo: Path) -> None:
    items = DocsMarkerCollector().collect(repo)
    assert [item.location for item in items] == ["docs/05-safety.md:3", "docs/sub/x.md:1"]
    assert items[0].summary == "Le service est conçu comme un cabinet."
    assert items[0].status == "à valider"


def test_prompt_collector_reports_only_unreviewed_prompts(repo: Path) -> None:
    items = PromptCollector().collect(repo)
    assert [item.location for item in items] == ["packages/agents/prompts/estate/v1.md"]
    assert items[0].status == "draft"


def test_prompt_collector_without_prompts_dir(tmp_path: Path) -> None:
    assert PromptCollector().collect(tmp_path) == []


def test_parse_front_matter_requires_header() -> None:
    with pytest.raises(ValueError, match="en-tête YAML"):
        parse_front_matter("pas d'en-tête", source=Path("p.md"))
    with pytest.raises(ValueError, match="dictionnaire"):
        parse_front_matter("---\n- liste\n---\n", source=Path("p.md"))


def test_summarize_line_truncates() -> None:
    assert summarize_line("- " + "a" * 200, max_length=10) == "aaaaaaaaa…"
    assert summarize_line("| x [À VALIDER] y |") == "x y"


def test_render_report_groups_by_category() -> None:
    items = [
        PendingItem("prompts", "p/v1.md", "prompt", "draft"),
        PendingItem("docs", "d.md:1", "un point", "à valider"),
    ]
    text = render_report(items, generated_at=datetime(2026, 9, 18, tzinfo=UTC), commit="abc123")
    assert "Généré le 2026-09-18T00:00:00+00:00 au commit `abc123`." in text
    assert "**Total : 2 élément(s) en attente.**" in text
    assert text.index("## docs (1)") < text.index("## prompts (1)")
    assert "| `d.md:1` | à valider | un point |" in text


def test_write_report_creates_output(repo: Path) -> None:
    target, items = write_report(repo, Path("reports/validation.md"))
    assert target == repo / "reports" / "validation.md"
    assert len(items) == len(collect_pending(repo)) == 3
    assert target.read_text(encoding="utf-8").startswith("# Rapport de validation")


def test_find_repo_root(repo: Path) -> None:
    nested = repo / "docs" / "sub"
    assert find_repo_root(nested) == repo
    with pytest.raises(RepoRootNotFoundError):
        find_repo_root(Path("/"))


def test_cli_validation_report(repo: Path) -> None:
    result = CliRunner().invoke(main, ["validation-report", "--repo-root", str(repo)])
    assert result.exit_code == 0, result.output
    assert result.output.startswith("3 élément(s) en attente de validation")
    assert (repo / "reports" / "validation.md").is_file()


def test_cli_version() -> None:
    result = CliRunner().invoke(main, ["--version"])
    assert result.exit_code == 0
    assert result.output.startswith("cgp, version ")
