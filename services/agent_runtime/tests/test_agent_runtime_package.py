"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_agent_runtime


def test_package_exposes_installed_version() -> None:
    assert cgp_agent_runtime.__version__ == version("cgp-agent-runtime")
