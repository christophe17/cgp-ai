"""Rapport de validation : inventaire du contenu métier en attente d'une relecture professionnelle.

Le rapport est spécifié dans `docs/06-evals-mlops.md` §8. Aucune relecture n'est prévue dans ce
projet : tout reste `draft`, et le rapport le montre. Chaque famille de contenu est produite par un
collecteur ; en phase 0 il en existe deux (marqueurs **[À VALIDER]** de `docs/`, prompts sans
relecteur). Les collecteurs des paramètres, des cas du moteur, des règles de conformité et des cas
de référence s'ajoutent à la phase qui crée ces contenus.
"""

from __future__ import annotations

import re
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Protocol

import yaml

VALIDATION_MARKER = "[À VALIDER]"
DEFAULT_OUTPUT = Path("reports/validation.md")

_FRONT_MATTER = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)


@dataclass(frozen=True, slots=True)
class PendingItem:
    """Un contenu qui attendrait une validation professionnelle."""

    category: str
    location: str
    summary: str
    status: str


class Collector(Protocol):
    """Un collecteur inventorie une famille de contenu du dépôt."""

    name: str

    def collect(self, repo_root: Path) -> list[PendingItem]:
        """Renvoie les éléments en attente trouvés sous `repo_root`."""
        ...


class DocsMarkerCollector:
    """Relève chaque ligne de `docs/` portant le marqueur **[À VALIDER]**."""

    name = "docs"
    docs_dir = Path("docs")

    def collect(self, repo_root: Path) -> list[PendingItem]:
        """Parcourt `docs/**/*.md` et relève les lignes marquées."""
        items: list[PendingItem] = []
        for path in sorted((repo_root / self.docs_dir).rglob("*.md")):
            lines = path.read_text(encoding="utf-8").splitlines()
            for lineno, line in enumerate(lines, start=1):
                if VALIDATION_MARKER in line:
                    items.append(
                        PendingItem(
                            category=self.name,
                            location=f"{path.relative_to(repo_root)}:{lineno}",
                            summary=summarize_line(line),
                            status="à valider",
                        )
                    )
        return items


class PromptCollector:
    """Relève les prompts versionnés dont l'en-tête `reviewed_by` est vide."""

    name = "prompts"
    prompts_dir = Path("packages/agents/prompts")

    def collect(self, repo_root: Path) -> list[PendingItem]:
        """Parcourt `packages/agents/prompts/<agent>/vN.md`."""
        root = repo_root / self.prompts_dir
        if not root.is_dir():
            return []
        items: list[PendingItem] = []
        for path in sorted(root.glob("*/v*.md")):
            metadata = parse_front_matter(path.read_text(encoding="utf-8"), source=path)
            if metadata.get("reviewed_by") is None:
                items.append(
                    PendingItem(
                        category=self.name,
                        location=str(path.relative_to(repo_root)),
                        summary=f"prompt `{path.parent.name}` version `{path.stem}`",
                        status="draft",
                    )
                )
        return items


def parse_front_matter(text: str, *, source: Path) -> dict[str, object]:
    """Extrait l'en-tête YAML délimité par `---` en tête d'un prompt.

    Raises:
        ValueError: si l'en-tête est absent ou n'est pas un dictionnaire.
    """
    match = _FRONT_MATTER.match(text)
    if match is None:
        raise ValueError(f"{source}: en-tête YAML (---) absent")
    loaded = yaml.safe_load(match.group(1))
    if not isinstance(loaded, dict):
        raise ValueError(f"{source}: l'en-tête YAML doit être un dictionnaire")
    return {str(key): value for key, value in loaded.items()}


def summarize_line(line: str, max_length: int = 120) -> str:
    """Résumé d'une ligne marquée : sans le marqueur, sans la ponctuation Markdown, tronqué."""
    text = " ".join(line.replace(VALIDATION_MARKER, " ").split()).strip("-*#|> ")
    if len(text) <= max_length:
        return text
    return text[: max_length - 1] + "…"


DEFAULT_COLLECTORS: tuple[Collector, ...] = (DocsMarkerCollector(), PromptCollector())


def collect_pending(
    repo_root: Path, collectors: Iterable[Collector] = DEFAULT_COLLECTORS
) -> list[PendingItem]:
    """Concatène les éléments de tous les collecteurs, dans l'ordre des collecteurs."""
    items: list[PendingItem] = []
    for collector in collectors:
        items.extend(collector.collect(repo_root))
    return items


def render_report(
    items: Sequence[PendingItem], *, generated_at: datetime, commit: str | None
) -> str:
    """Rend le rapport en Markdown, regroupé par catégorie."""
    lines = [
        "# Rapport de validation",
        "",
        f"Généré le {generated_at.isoformat(timespec='seconds')}"
        + (f" au commit `{commit}`" if commit else "")
        + ".",
        "",
        (
            "Aucune validation professionnelle n'est prévue dans ce projet : tout contenu métier "
            "reste `draft`. Ce rapport liste ce qu'une relecture devrait couvrir."
        ),
        "",
        f"**Total : {len(items)} élément(s) en attente.**",
        "",
    ]
    categories = sorted({item.category for item in items})
    for category in categories:
        subset = [item for item in items if item.category == category]
        lines.extend(
            [
                f"## {category} ({len(subset)})",
                "",
                "| Emplacement | Statut | Résumé |",
                "|---|---|---|",
            ]
        )
        lines.extend(f"| `{item.location}` | {item.status} | {item.summary} |" for item in subset)
        lines.append("")
    return "\n".join(lines)


def write_report(
    repo_root: Path,
    output: Path = DEFAULT_OUTPUT,
    *,
    collectors: Iterable[Collector] = DEFAULT_COLLECTORS,
    commit: str | None = None,
    generated_at: datetime | None = None,
) -> tuple[Path, list[PendingItem]]:
    """Collecte, rend et écrit le rapport ; renvoie le chemin écrit et les éléments."""
    items = collect_pending(repo_root, collectors)
    report = render_report(items, generated_at=generated_at or datetime.now(tz=UTC), commit=commit)
    target = output if output.is_absolute() else repo_root / output
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(report, encoding="utf-8")
    return target, items
