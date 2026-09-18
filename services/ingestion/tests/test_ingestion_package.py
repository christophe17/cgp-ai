"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_ingestion


def test_package_exposes_installed_version() -> None:
    assert cgp_ingestion.__version__ == version("cgp-ingestion")
