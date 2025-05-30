//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import {Ownable} from "./Ownable.sol";
import {Diddy} from "./Diddy.sol";

contract DiddyToken is Ownable, ERC20, AccessControl {
    //////////////
    /// Variables ///
    //////////////
    string private _name = "Diddy";
    string private _symbol = "DDS";
    uint8 private immutable _decimals = 6;
    uint256 private _totalSupply;

    //////////////
    /// Mappings ///
    // Mapping from address to balance
    // Mapping from owner to spender to allowance
    // These mappings are used to track balances and allowances for the ERC20 token
    // when mapping it will be good to add names to be more clarified in complexed
    //////////////
    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    //////////////
    /// Events ///
    /////////////

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    //////////////
    /// Roles ///
    ////////////
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    //////////////
    //// Errors///
    //////////////

    error InsufficientBalance();
    error InsufficientAllowance();
    error ZeroAddress();
    error AmountZero();

    constructor() Ownable(msg.sender) ERC20("Diddy", "DDS") {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(MINTER_ROLE, _msgSender());
        _grantRole(BURNER_ROLE, _msgSender());

        uint256 initialSupply = 100 * (10 ** _decimals); // 100 Diddy tokens with 6 decimals
        _totalSupply = initialSupply;
        _balances[msg.sender] = initialSupply; // Assign all tokens to the contract deployer
        emit Transfer(address(0), msg.sender, initialSupply); // Emit transfer event for initial supply
    }

    //////////////
    /// Standart Functions ///
    //////////////

    /// @notice Returns the name of the token.
    function name() external view returns (string memory) {
        return _name;
    }

    /// @notice Returns the symbol of the token.
    function symbol() external view returns (string memory) {
        return _symbol;
    }

    /// @notice Returns the number of decimals used by the token.
    function decimals() external view returns (uint8) {
        return _decimals;
    }

    /// @notice Returns the total supply of the token.
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice Returns the balance of a specific account.
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @notice Returns the allowance of a spender for a specific owner's tokens.
    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    /// Minting with AccessControl
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        _mint(to, amount);
    }

    /// Burning with AccessControl
    function burn(uint256 amount) external onlyRole(BURNER_ROLE) {
        if (_balances[_msgSender()] < amount) revert InsufficientBalance();
        if (amount == 0) revert AmountZero();
        _burn(_msgSender(), amount);
    }

    //////////////
    /// Setters ///
    //////////////
    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();
        if (_balances[from] < amount) revert InsufficientBalance();
        if (_allowances[from][msg.sender] < amount) revert InsufficientAllowance();

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external onlyOwner returns (bool) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert AmountZero();

        _totalSupply += amount;
        _balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(uint256 amount) external returns (bool) {
        if (amount == 0) revert AmountZero();
        if (_balances[msg.sender] < amount) revert InsufficientBalance();

        _balances[msg.sender] -= amount;
        _totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}
