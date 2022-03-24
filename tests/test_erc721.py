import pytest

from brownie import ZERO_ADDRESS, accounts


def test_minting(erc721):
    assert erc721.totalSupply() == 0
    tx = erc721.mint(accounts[1], "http://hello/bob")
    assert erc721.totalSupply() == 1
    assert tx.events["Transfer"].values() == [ZERO_ADDRESS, accounts[1], 1]
    assert erc721.tokenURI(1) == "http://hello/bob"


def test_interfaces(erc721):
    pass
