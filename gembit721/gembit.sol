pragma solidity >=0.4.22 <0.7.0;

import "../interfaces/ierc165.sol";
import "../interfaces/ierc721.sol";
import "../interfaces/ierc721receiver.sol";

contract gembit is ERC721, ERC165 {
    address _minter;
    uint256 _totalCoins;
    uint16 _numTypes;
    mapping(uint16=>string) _typesCoin;
    mapping(uint16=>uint256) _numCoins;
    mapping(address=>mapping(uint16=>uint256)) _balance;
    uint16 _maxType = 16;
    mapping(uint256=>address) _tokenOwner;
    mapping (address => mapping (address => bool)) _ownerToOperators;
    mapping (uint256 => address) internal _idToApproval;
    bytes4 internal constant MAGIC_ON_ERC721_RECEIVED = 0x150b7a02;

    constructor() public {
        _minter=msg.sender;
    }

    function newCoin(string calldata name, uint256 amount) external payable {
        require(msg.sender == _minter, "Not authorized!");
        require(amount<=1000000000000, "Amount too large!");
        _typesCoin[_numTypes] = name;
        _numCoins[_numTypes] = amount;
        _balance[msg.sender][_numTypes] = amount;
        _numTypes += 1;
        _totalCoins += amount;
        for (uint256 i = (_numTypes-1)*(2**252); i < (_numTypes-1)*(2**252)+amount; i++) {
            _tokenOwner[i] = msg.sender;
        }
    }

    function mint(string calldata name, uint256 amount) external payable {
        require(msg.sender == _minter, "Not authorized!");
        require(amount<=1000000000000, "Amount too large!");
        uint16 index = 0;
        for (; index < _numTypes; index++) {
            if (keccak256(bytes(_typesCoin[index])) == keccak256(bytes(name))) {
                break;
            }
        }
        require(index!=_numTypes, "No coin of given type!");
        uint256 curr = _numCoins[index];
        for (uint256 i = curr; i < curr+amount; i++) {
            _tokenOwner[i] = msg.sender;
        }
        _numCoins[index] += amount;
        _balance[msg.sender][index] += amount;
        _totalCoins += amount;
        
    }

    function supportsInterface(bytes4 interfaceID) external view override returns (bool) {
        return (interfaceID == 0x80ac58cd);
    }

    /// @dev This emits when ownership of any NFT changes by any mechanism.
    ///  This event emits when NFTs are created (`from` == 0) and destroyed
    ///  (`to` == 0). Exception: during contract creation, any number of NFTs
    ///  may be created and assigned without emitting Transfer. At the time of
    ///  any transfer, the approved address for that NFT (if any) is reset to none.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev This emits when the approved address for an NFT is changed or
    ///  reaffirmed. The zero address indicates there is no approved address.
    ///  When a Transfer event emits, this also indicates that the approved
    ///  address for that NFT (if any) is reset to none.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @dev This emits when an operator is enabled or disabled for an owner.
    ///  The operator can manage all NFTs of the owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);


    /// @notice Count all NFTs assigned to an owner
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _owner An address for whom to query the balance
    /// @return The number of NFTs owned by `_owner`, possibly zero
    function balanceOf(address _owner) external view override returns (uint256) {
        uint256 total = 0;
        for (uint16 i = 0; i < _numTypes; i++) {
            total += _balance[_owner][i];
        }
        return total;
    }

    function balanceOf(address _owner, string calldata coinType) external view returns (uint256) {
        uint16 index = 0;
        for (; index < _numTypes; index++) {
            if (keccak256(bytes(_typesCoin[index])) == keccak256(bytes(coinType))) {
                break;
            }
        }
        require(index!=_numTypes, "No coin of given type!");
        return _balance[_owner][index];
    }

    function balanceOf(address _owner, uint16 index) external view returns (uint256) {
        require(index<_numTypes, "No coin of given index!");
        return _balance[_owner][index];
    }
    /// @notice Find the owner of an NFT
    /// @dev NFTs assigned to zero address are considered invalid, and queries
    ///  about them do throw.
    /// @param _tokenId The identifier for an NFT
    /// @return The address of the owner of the NFT
    function ownerOf(uint256 _tokenId) external view override returns (address) {
        require(_tokenOwner[_tokenId] != address(0), "Token does not exist!");
        return _tokenOwner[_tokenId];
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT. When transfer is complete, this function
    ///  checks if `_to` is a smart contract (code size > 0). If so, it calls
    ///  `onERC721Received` on `_to` and throws if the return value is not
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    /// @param _data Additional data with no specified format, sent in call to `_to`
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external override payable {
        require(msg.sender == _tokenOwner[_tokenId] || _ownerToOperators[_from][msg.sender] || _idToApproval[_tokenId]==msg.sender, "Invalid Operation.");
        require(_from!=_tokenOwner[_tokenId], "'from' field is not the token owner.");

        uint16 noCoin = (uint16)(_tokenId / (2**252));
        require(noCoin<_numTypes && (_tokenId-noCoin*(2**252)<_numCoins[noCoin]), "No coin with the given address.");
        transfer(_from, _to, _tokenId);
        if (isContract(_to)) {
            bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data);
            require(retval == MAGIC_ON_ERC721_RECEIVED, "Target account not able to receive token");
        }
    }

    /// @notice Transfers the ownership of an NFT from one address to another address
    /// @dev This works identically to the other function with an extra data parameter,
    ///  except this function just sets data to "".
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external override payable {
        require(msg.sender == _tokenOwner[_tokenId] || _ownerToOperators[_from][msg.sender] || _idToApproval[_tokenId]==msg.sender, "Invalid Operation.");
        require(_from!=_tokenOwner[_tokenId], "'from' field is not the token owner.");

        uint16 noCoin = (uint16)(_tokenId / (2**252));
        require(noCoin<_numTypes && (_tokenId-noCoin*(2**252)<_numCoins[noCoin]), "No coin with the given address.");
        transfer(_from, _to, _tokenId);
        if (isContract(_to)) {
            bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(msg.sender, _from, _tokenId, "");
            require(retval == MAGIC_ON_ERC721_RECEIVED, "Target account not able to receive token");
        }
    }

    /// @notice Transfer ownership of an NFT -- THE CALLER IS RESPONSIBLE
    ///  TO CONFIRM THAT `_to` IS CAPABLE OF RECEIVING NFTS OR ELSE
    ///  THEY MAY BE PERMANENTLY LOST
    /// @dev Throws unless `msg.sender` is the current owner, an authorized
    ///  operator, or the approved address for this NFT. Throws if `_from` is
    ///  not the current owner. Throws if `_to` is the zero address. Throws if
    ///  `_tokenId` is not a valid NFT.
    /// @param _from The current owner of the NFT
    /// @param _to The new owner
    /// @param _tokenId The NFT to transfer
    function transferFrom(address _from, address _to, uint256 _tokenId) external override payable {
        require(msg.sender == _tokenOwner[_tokenId] || _ownerToOperators[_from][msg.sender] || _idToApproval[_tokenId]==msg.sender, "Invalid Operation.");
        require(_from!=_tokenOwner[_tokenId], "'from' field is not the token owner.");

        uint16 noCoin = (uint16)(_tokenId / (2**252));
        require(noCoin<_numTypes && (_tokenId-noCoin*(2**252)<_numCoins[noCoin]), "No coin with the given address.");
        transfer(_from, _to, _tokenId);
    }


    function transfer(address _from, address _to, uint256 _tokenId) internal {
        _idToApproval[_tokenId] = address(0);
        _tokenOwner[_tokenId] = _to;
        _balance[_from][(uint16)(_tokenId/(2**252))] -= 1;
        _balance[_to][(uint16)(_tokenId/(2**252))] -= 1;
        emit Transfer(_from, _to, _tokenId);
    }

    /// @notice Change or reaffirm the approved address for an NFT
    /// @dev The zero address indicates there is no approved address.
    ///  Throws unless `msg.sender` is the current NFT owner, or an authorized
    ///  operator of the current owner.
    /// @param _approved The new approved NFT controller
    /// @param _tokenId The NFT to approve
    function approve(address _approved, uint256 _tokenId) external payable override {
        require(msg.sender == _tokenOwner[_tokenId] || _ownerToOperators[_tokenOwner[_tokenId]][msg.sender], "Not authorized!");
        _idToApproval[_tokenId] = _approved;
        emit Approval(_tokenOwner[_tokenId], _approved, _tokenId);
    }

    /// @notice Enable or disable approval for a third party ("operator") to manage
    ///  all of `msg.sender`'s assets
    /// @dev Emits the ApprovalForAll event. The contract MUST allow
    ///  multiple operators per owner.
    /// @param _operator Address to add to the set of authorized operators
    /// @param _approved True if the operator is approved, false to revoke approval
    function setApprovalForAll(address _operator, bool _approved) external override {
        _ownerToOperators[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @notice Get the approved address for a single NFT
    /// @dev Throws if `_tokenId` is not a valid NFT.
    /// @param _tokenId The NFT to find the approved address for
    /// @return The approved address for this NFT, or the zero address if there is none
    function getApproved(uint256 _tokenId) external view override returns (address) {
        return _idToApproval[_tokenId];
    }

    /// @notice Query if an address is an authorized operator for another address
    /// @param _owner The address that owns the NFTs
    /// @param _operator The address that acts on behalf of the owner
    /// @return True if `_operator` is an approved operator for `_owner`, false otherwise
    function isApprovedForAll(address _owner, address _operator) external view override returns (bool) {
        return _ownerToOperators[_owner][_operator];
    }

    function isContract(
    address _addr
  )
    internal
    view
    returns (bool addressCheck)
  {
    // This method relies in extcodesize, which returns 0 for contracts in
    // construction, since the code is only stored at the end of the
    // constructor execution.

    // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
    // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
    // for accounts without code, i.e. `keccak256('')`
    bytes32 codehash;
    bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
    assembly { codehash := extcodehash(_addr) } // solhint-disable-line
    addressCheck = (codehash != 0x0 && codehash != accountHash);
  }
}