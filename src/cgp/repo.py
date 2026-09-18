"""Localisation de la racine du dépôt et du commit courant."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

ROOT_MARKER = "CLAUDE.md"


class RepoRootNotFoundError(RuntimeError):
    """Aucun ancêtre du répertoire de départ ne contient le marqueur de racine."""


def find_repo_root(start: Path) -> Path:
    """Remonte depuis `start` jusqu'au répertoire contenant `CLAUDE.md`.

    Args:
        start: répertoire (ou fichier) de départ.

    Returns:
        Le répertoire racine du dépôt.

    Raises:
        RepoRootNotFoundError: si aucun ancêtre ne contient le marqueur.
    """
    for candidate in (start, *start.resolve().parents):
        if (candidate / ROOT_MARKER).is_file():
            return candidate
    raise RepoRootNotFoundError(f"aucun ancêtre de {start} ne contient {ROOT_MARKER}")


def current_commit(repo_root: Path) -> str | None:
    """Renvoie le SHA court du commit courant, ou `None` hors dépôt git ou sans commit."""
    git = shutil.which("git")
    if git is None:
        return None
    completed = subprocess.run(  # noqa: S603 - exécutable résolu par shutil.which, arguments fixes
        [git, "-C", str(repo_root), "rev-parse", "--short", "HEAD"],
        capture_output=True,
        text=True,
        check=False,
        timeout=10,
    )
    if completed.returncode != 0:
        return None
    return completed.stdout.strip() or None
