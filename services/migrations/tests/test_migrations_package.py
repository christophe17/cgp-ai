"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_migrations


def test_package_exposes_installed_version() -> None:
    assert cgp_migrations.__version__ == version("cgp-migrations")
