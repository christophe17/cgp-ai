"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_domain


def test_package_exposes_installed_version() -> None:
    assert cgp_domain.__version__ == version("cgp-domain")
