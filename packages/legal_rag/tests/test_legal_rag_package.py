"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_legal_rag


def test_package_exposes_installed_version() -> None:
    assert cgp_legal_rag.__version__ == version("cgp-legal-rag")
