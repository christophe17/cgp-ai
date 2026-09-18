"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_agents


def test_package_exposes_installed_version() -> None:
    assert cgp_agents.__version__ == version("cgp-agents")
