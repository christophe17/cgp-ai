"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_tools_lambda


def test_package_exposes_installed_version() -> None:
    assert cgp_tools_lambda.__version__ == version("cgp-tools-lambda")
