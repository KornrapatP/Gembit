pragma solidity ^0.4.24;
import "../interfaces/ierc20.sol";

contract gemBit is ERC20 {
    address _minter;
    uint256 _total;
    mapping(address=>uint256) _balance;
    mapping(address=>mapping(address=>uint256)) _allowance;
    string _name;
    string _sym;

    constructor(string name, string abr) public {
        _minter = msg.sender;
        _name = name;
        _sym = abr;
    }
    function name() public view returns (string) {
        return _name;
    }
    
    function symbol() public view returns (string) {
        return _sym;
    }

    function mint(uint256 amount) external {
        require(msg.sender == _minter, "Not authorized!");
        _total += amount;
        _balance[_minter] += amount;
    }

    function totalSupply() external view returns (uint256) {
        return _total;
    }

    function balanceOf(address who) external view returns (uint256) {
        return _balance[who];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowance[owner][spender];
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(_balance[msg.sender] >= value, "Not enough funds!");
        _balance[msg.sender] -= value;
        _balance[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        if (msg.sender == from) {
            require(_balance[msg.sender] >= value, "Not enough funds!");
            _balance[msg.sender] -= value;
            _balance[to] += value;
            emit Transfer(msg.sender, to, value);
            return true;
        }
        uint256 allow = _allowance[from][msg.sender];
        require(_balance[from] >= value && allow >= value, "Not enough allowance");
        _allowance[from][msg.sender] -= value;
        _balance[from] -= value;
        _balance[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
    
    
}