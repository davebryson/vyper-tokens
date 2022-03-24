# @version ^0.3.1

"""
@title ERC721
@license Apache-2.0
@author Dave Bryson
@notice Implementation of ERC721 with the following optional extensions:
proper ERC-165, Enumerable, and Metadata.
"""
from vyper.interfaces import ERC721

implements: ERC721

# @dev Handle the receipt of an NFT when safeTransferFrom is called.
interface ERC721Receiver:
    def onERC721Received(
            _operator: address,
            _from: address,
            _tokenId: uint256,
            _data: Bytes[1024]
        ) -> bytes32: view

# @dev Supports returning metadata about the NFT
interface ERC721Metadata:
    # @return the name of the NFT
    def name() -> String[64]: view
    # @return the symbol
    def symbol() -> String[32]: view
    # @return the token URI. Note: the restriction of size.
    def tokenURI(_tokenid: uint256) -> String[256]: view

interface ERC721Enumerable:
    # @return the total number of NFTs
    def tokenSupply() -> uint256: view
    # @return the token identifier for the index'th NFT
    def tokenByIndex(_index: uint256) -> uint256: view 
    # @return the token identifier for the index'th NFT assigned to '_owner'
    def tokenOfOwnerByIndex(_owner: address, _index: uint256) -> uint256: view

## Events ##

# @dev Emits when ownership of any NFT changes by any mechanism. This event emits when NFTs are
#      created (`from` == 0) and destroyed (`to` == 0). Exception: during contract creation, any
#      number of NFTs may be created and assigned without emitting Transfer. At the time of any
#      transfer, the approved address for that NFT (if any) is reset to none.
# @param _from Sender of NFT (if address is zero address it indicates token creation).
# @param _to Receiver of NFT (if address is zero address it indicates token destruction).
# @param _tokenId The NFT that got transfered.
event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    tokenId: indexed(uint256)

# @dev Emits when the approved address for an NFT is changed or reaffirmed. The zero
#      address indicates there is no approved address. When a Transfer event emits, this also
#      indicates that the approved address for that NFT (if any) is reset to none.
# @param _owner Owner of NFT.
# @param _approved Address that we are approving.
# @param _tokenId NFT which we are approving.
event Approval:
    owner: indexed(address)
    approved: indexed(address)
    tokenId: indexed(uint256)

# @dev Emits when an operator is enabled or disabled for an owner. The operator can manage
#      all NFTs of the owner.
# @param _owner Owner of NFT.
# @param _operator Address to which we are setting operator rights.
# @param _approved Status of operator rights(true if operator rights are given and false if
# revoked).
event ApprovalForAll:
    owner: indexed(address)
    operator: indexed(address)
    approved: bool


## Metadata state ##
name: public(String[64])
symbol: public(String[32])

## Enumerable state ##

# Used for totalSupply and counter for tokenids
token_count: uint256

# Burned 
tokens_burned: uint256

# token id to index
tokenid_to_index: HashMap[uint256, uint256]
# index to token id
index_to_tokenid: HashMap[uint256, uint256]
# owner to indexed (list) of token ids
owner_to_index_tokenid: HashMap[address, HashMap[uint256, uint256]]
# tokenid to owner index
tokenid_to_owner_index: HashMap[uint256, uint256]

## URI storage ##
tokenid_to_uri: HashMap[uint256, String[256]]

## 721 ## 

# Minter
minter: address

# token id to owner address
tokenid_to_owner: HashMap[uint256, address]
# owner to the count of their tokens
owner_to_token_count: HashMap[address, uint256]
# token id to approved address
tokenid_to_approved: HashMap[uint256, address]
# owner to 1 or more approved operators
owner_to_operators: HashMap[address, HashMap[address, bool]]

## ERC-165 interface identifiers ## 

# @dev Interface ID of ERC721Metadata
ERC721_METADATA_INTERFACE_ID: constant(Bytes[32]) = b'[^\x13\x9f'
# @dev Interface ID of ERC721Enumerable
ERC721_ENUMERABLE_INTERFACE_ID: constant(Bytes[32]) = b'x\x0e\x9dc'

@external
def __init__(_name: String[64], _symbol: String[32]):
    self.name = _name 
    self.symbol = _symbol
    self.minter = msg.sender

## Views ##

@view
@external
def supportsInterface(_interfaceid: bytes32) -> bool:
    four_bytes: Bytes[4] = slice(_interfaceid, 28, 4)

    return (four_bytes == ERC721_METADATA_INTERFACE_ID) or \
    (four_bytes == ERC721_ENUMERABLE_INTERFACE_ID)

@view 
@internal
def _balance_of(_to: address) -> uint256: 
    assert _to != ZERO_ADDRESS
    return self.owner_to_token_count[_to]

@view
@internal 
def _total_supply() -> uint256:
    return self.token_count - self.tokens_burned

@view 
@external
def tokenURI(_tokenid: uint256) -> String[256]:
    """
    Required by Metadata
    """
    return self.tokenid_to_uri[_tokenid]

@view
@external
def balanceOf(_to: address) -> uint256:
    """
    Required by 721
    """ 
    return self._balance_of(_to)

@view 
@external
def totalSupply() -> uint256:
    """
    Required by Enumerable
    """
    return self._total_supply()

@view 
@external
def tokenByIndex(_index: uint256) -> uint256:
    """
    Required by Enumerable
    """
    return self.index_to_tokenid[_index]

@view 
@external
def tokenOfOwnerByIndex(_owner: address, _index: uint256) -> uint256:
    """
    Required by Enumerable
    """
    return self.owner_to_index_tokenid[_owner][_index]

@view
@external
def ownerOf(_tokenid: uint256) -> address:
    """
    Required by 721
    """
    return self.tokenid_to_owner[_tokenid]

@internal
def _add_token_to_owner_list(_to: address, _tokenid: uint256):
    count: uint256 = self._balance_of(_to)
    self.owner_to_index_tokenid[_to][count] = _tokenid
    self.tokenid_to_owner_index[_tokenid] = count

@internal
def _add_token(_to: address, _tokenid: uint256):
    # make sure token doesn't exist
    assert self.tokenid_to_owner[_tokenid] == ZERO_ADDRESS
    self.tokenid_to_owner[_tokenid] = _to
    self.owner_to_token_count[_to] += 1
    self._add_token_to_owner_list(_to, _tokenid)

@internal 
def _set_token_uri(_tokenid: uint256, _uri: String[256]):
    self.tokenid_to_uri[_tokenid] = _uri

@internal
def _clear_approvals(_owner: address, _tokenid: uint256):
    assert self.tokenid_to_owner[_tokenid] == _owner
    self.tokenid_to_approved[_tokenid] = ZERO_ADDRESS

@internal 
def _remove_token_from_owner_list(_from: address, _tokenid: uint256):
    count: uint256 = self._balance_of(_from)
    index: uint256 = self.tokenid_to_owner_index[_tokenid]

    if count == index:
        # There's only 1 in our list 
        # delete
        self.owner_to_index_tokenid[_from][count] = 0
        self.tokenid_to_owner_index[_tokenid] = 0
    else:
        last_tokenid: uint256 = self.owner_to_index_tokenid[_from][count]
        self.owner_to_index_tokenid[_from][index] = last_tokenid
        self.tokenid_to_owner_index[last_tokenid] = index

        self.owner_to_index_tokenid[_from][count] = 0
        self.tokenid_to_owner_index[_tokenid] = 0

## Transfers ## 

@internal
def _is_approved_or_owner(_spender: address, _tokenid: uint256) -> bool:
    owner: address = self.tokenid_to_owner[_tokenid]
    if owner == ZERO_ADDRESS:
        return False
    if owner != _spender: 
        return False
    if _spender != self.tokenid_to_approved[_tokenid]:
        return False 
    return (self.owner_to_operators[owner])[_spender]


@internal
def _transfer_from(_from: address, _to: address, _tokenid: uint256, _sender: address):
    assert self._is_approved_or_owner(_sender, _tokenid)
    assert _to != ZERO_ADDRESS
    
    self._clear_approvals(_from, _tokenid)
    self._remove_token_from_owner_list(_from, _tokenid)
    self._add_token(_to, _tokenid)
    
    log Transfer(_from, _to, _tokenid)


@payable
@external
def transferFrom(_from: address, _to: address, _tokenid: uint256):
    self._transfer_from(_from, _to, _tokenid, msg.sender)

@payable
@external
def safeTransferFrom(_from: address, _to: address, _tokenid: uint256, _data: Bytes[1024]=b""):
    self._transfer_from(_from, _to, _tokenid, msg.sender)
    
    if _to.is_contract:
        # make sure receiver is an NFT
        res: bytes32 = ERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenid, _data)
        assert res == method_id("onERC721Received(address,address,uint256,bytes)", output_type=bytes32)

## Approvals ##

@payable 
@external 
def approve(_approved: address, _tokenid: uint256):
    owner: address = self.tokenid_to_owner[_tokenid]
    assert owner != ZERO_ADDRESS
    assert _approved != owner

    # assert sender is owner
    approved_for_all: bool = (self.owner_to_operators[owner])[msg.sender] 
    assert (msg.sender == owner) or approved_for_all
    self.tokenid_to_approved[_tokenid] = _approved

    log Approval(owner, _approved, _tokenid)

@external
def setApprovalForAll(_operator: address, _approved: bool):
    assert _operator != ZERO_ADDRESS
    assert _operator != msg.sender
    self.owner_to_operators[msg.sender][_operator] = _approved
    
    log ApprovalForAll(msg.sender, _operator, _approved)

@view
@external
def getApproved(_tokenid: uint256) -> address:
    assert self.tokenid_to_owner[_tokenid] != ZERO_ADDRESS
    return self.tokenid_to_approved[_tokenid]

@view 
@external
def isApprovedForAll(_owner: address, _operator: address) -> bool:
    return self.owner_to_operators[_owner][_operator]

## Mint/Burn ## 

@external
def mint(_to: address, _token_uri: String[256]) -> bool:
    assert msg.sender == self.minter
    assert _to != ZERO_ADDRESS

    self.token_count += 1
    tokenid: uint256 = self.token_count
    self._add_token(_to, tokenid)

    # Current index 
    idx: uint256 = self._total_supply()
    # index to tokenid
    self.index_to_tokenid[idx] = tokenid
    # tokenid to index
    self.tokenid_to_index[tokenid] = idx
    # set token URL 
    self._set_token_uri(tokenid, _token_uri)
    
    log Transfer(ZERO_ADDRESS, _to, tokenid)
    return True

@external 
def burn(_tokenid: uint256):

    assert self._is_approved_or_owner(msg.sender, _tokenid)
    owner: address = self.tokenid_to_owner[_tokenid]
    assert owner != ZERO_ADDRESS

    self._clear_approvals(owner, _tokenid)
    self._remove_token_from_owner_list(owner, _tokenid)

    index: uint256 = self.tokenid_to_index[_tokenid]
    last_index: uint256 = self._total_supply() - self.tokens_burned
    last_tokenid: uint256 = self.index_to_tokenid[last_index]

    self.index_to_tokenid[index] = last_tokenid
    self.tokenid_to_index[last_tokenid] = index

    self.tokenid_to_index[_tokenid] = 0
    self.tokens_burned += 1
    log Transfer(owner, ZERO_ADDRESS, _tokenid)


### Add code to extend this NFT below ###


