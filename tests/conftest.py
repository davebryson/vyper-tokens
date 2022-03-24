import pytest
from brownie import accounts

# isolation setup
@pytest.fixture(autouse=True)
def isolation_setup(fn_isolation):
    pass


# ERC721
@pytest.fixture(scope="module")
def erc721(ERC721):
    e = accounts[0].deploy(ERC721, "Sample", "SAMP")
    yield e
