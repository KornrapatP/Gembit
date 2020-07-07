pragma solidity ^0.4.24;
import "../interfaces/ierc20.sol";

contract gemBit is ERC20 {
    address _minter;
    uint256 _total;
    mapping(address=>uint256) _balance;
    mapping(address=>mapping(address=>uint256)) _allowance;

    constructor() public {
        _minter = msg.sender;
    }

    function mint(uint256 amount) external {
        require(msg.sender == _minter, "Not authorized!");
        _total += amount;
        _balance[_minter] += amount;
    }

    function totalSupply() external view override returns (uint256) {
        return _total
    }

    function balanceOf(address who) external view override returns (uint256) {
        return _balance[who];
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowance[owner][spender];
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        require(_balance[msg.sender] >= value, "Not enough funds!");
        _balance[msg.sender] -= value;
        _balance[to] += value;
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        if (msg.sender == from) {
            return transfer(to, value);
        }
        int256 allow = _allowance[from][msg.sender];
        require(balances[from] >= value && allow >= value, "Not enough allowance");
        allowed[from][msg.sender] -= value;
        _balance[from] -= value;
        _balance[to] += value;
        emit Transfer(from, to, value);
        return true;
    }
}