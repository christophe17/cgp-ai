"""Test de fumée : le package est installé et expose sa version."""

from importlib.metadata import version

import cgp_profile_api


def test_package_exposes_installed_version() -> None:
    assert cgp_profile_api.__version__ == version("cgp-profile-api")
