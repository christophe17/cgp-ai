"""Point d'entrée de la CLI `cgp`."""

from __future__ import annotations

from pathlib import Path

import click

from cgp import __version__
from cgp.repo import current_commit, find_repo_root
from cgp.validation_report import DEFAULT_OUTPUT, write_report


@click.group()
@click.version_option(__version__, prog_name="cgp")
def main() -> None:
    """CLI opérateur de la plateforme de conseil patrimonial multi-agents."""


@main.command("validation-report")
@click.option(
    "--repo-root",
    type=click.Path(file_okay=False, exists=True, path_type=Path),
    default=None,
    help="Racine du dépôt (détectée par défaut à partir du répertoire courant).",
)
@click.option(
    "--output",
    type=click.Path(dir_okay=False, path_type=Path),
    default=DEFAULT_OUTPUT,
    show_default=True,
    help="Fichier Markdown à écrire (relatif à la racine du dépôt).",
)
def validation_report(repo_root: Path | None, output: Path) -> None:
    """Génère le rapport du contenu métier en attente de validation."""
    root = repo_root or find_repo_root(Path.cwd())
    target, items = write_report(root, output, commit=current_commit(root))
    click.echo(f"{len(items)} élément(s) en attente de validation → {target}")
