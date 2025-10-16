// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

/**
 * @title KipuBank Contract
 * @author FeliPerdao
 * @notice Contract for token storage and deposit/withdraw functions similar to a bank. 
 *         There are limits on withdrawals per transaction. 
 *         The contract has a global deposit limit (bankCap) and tracks the number of deposits and withdrawals.
 * @dev This contract is for learning purposes only.
 * @custom:security Do not use this code in production.
 */

contract KipuBank {

    /*///////////////////////////////////////////
    ================ IMMUTABLES =================
    ///////////////////////////////////////////*/

    uint256 immutable public i_withdrawLimit; // withdrawal limit
    uint256 immutable public i_bankCap; // global bank limit

    /*///////////////////////////////////////////
    ============= STATE VARIABLES ===============
    ///////////////////////////////////////////*/

    ///@notice mapping representing personal accounts for each user
    mapping(address user => uint256 balance) public s_vaults;

    ///@notice total balance stored in the bank (all users combined)
    uint256 public s_totalBalance;

    ///@notice global counters for successful deposits and withdrawals
    uint256 public s_depositCount;
    uint256 public s_withdrawalCount;

    /*///////////////////////////////////////////
    ================= EVENTS ====================
    ///////////////////////////////////////////*/

    ///@notice events emitted for every successful deposit or withdrawal
    event DepositPerformed(address indexed user, uint256 amount, uint256 newVaultBalance);
    event WithdrawalPerformed(address indexed user, uint256 amount, uint256 newVaultBalance);

    /*///////////////////////////////////////////
    ================= ERRORS ====================
    ///////////////////////////////////////////*/

    ///@notice revert when a deposit attempt exceeds bankCap
    error BankCapExceeded(uint256 attemptedTotal, uint256 bankCap);

    ///@notice revert when the requested withdrawal exceeds the per-transaction limit
    error WithdrawalLimitExceeded(uint256 attemptedWithdraw, uint256 limit);

    ///@notice revert when the requested withdrawal exceeds the account balance
    error InsufficientFunds(address user, uint256 attemptedWithdraw, uint256 balance);

    ///@notice error when ETH transfer fails
    error TransactionFailed(bytes reason);

    ///@notice revert when a reentrancy attack is detected
    error ReentrancyDetected();

    /*///////////////////////////////////////////
    ============= REENTRANCY GUARD ==============
    ///////////////////////////////////////////*/

    uint256 private s_status;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        if (s_status == _ENTERED) revert ReentrancyDetected();
        s_status = _ENTERED;
        _;
        s_status = _NOT_ENTERED;
    }

    /*///////////////////////////////////////////
    ================ CONSTRUCTOR ================
    ///////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param _withdrawLimit maximum withdrawal per transaction (wei)
     * @param _bankCap global deposit limit (wei)
     */
    constructor(uint256 _withdrawLimit, uint256 _bankCap) {
        i_withdrawLimit = _withdrawLimit;
        i_bankCap = _bankCap;
        s_status = _NOT_ENTERED;
    }

    /*///////////////////////////////////////////
    ============= FALLBACK / RECEIVE ============
    ///////////////////////////////////////////*/

///@notice allows receiving ETH directly and treats it as a deposit
    receive() external payable{
        deposit();
    }

    fallback() external payable {
        deposit();
    }

    /*///////////////////////////////////////////
    ================= FUNCTIONS =================
    ///////////////////////////////////////////*/

    /**
     * @notice Deposit ETH into the "msg.sender" account
     * @dev follows the checks-effects-interactions pattern; reverts if the total bank balance exceeds the limit
     */
    function deposit() public payable {
        // -- checks --
        uint256 newTotalBalance = s_totalBalance + msg.value;
        if (newTotalBalance > i_bankCap) revert BankCapExceeded(newTotalBalance, i_bankCap);

        // -- effects --
        uint256 newVaultBalance = s_vaults[msg.sender] + msg.value;
        s_vaults[msg.sender] = newVaultBalance;
        s_totalBalance = newTotalBalance;
        unchecked { s_depositCount++; } // <- ver punto 2

        // -- interactions --
        emit DepositPerformed(msg.sender, msg.value, newVaultBalance);
    }

    /**
        * @notice ETH withdrawal
        * @param _amount value to withdraw (wei)
    */
    function withdraw(uint256 _amount) external nonReentrant {
        // -- checks --
        if (_amount > i_withdrawLimit) revert WithdrawalLimitExceeded(_amount, i_withdrawLimit);
        
        uint256 vaultBalance = s_vaults[msg.sender];
        if (_amount > vaultBalance) revert InsufficientFunds(msg.sender, _amount, vaultBalance);

        // -- effects --
        uint256 newVaultBalance;
        unchecked { newVaultBalance = vaultBalance - _amount; } // ver punto 2

        s_vaults[msg.sender] = newVaultBalance;
        s_totalBalance -= _amount;
        unchecked { s_withdrawalCount++; }

        // -- interactions --
        emit WithdrawalPerformed(msg.sender, _amount, newVaultBalance);
        _transferEth(msg.sender, _amount);
    }

    /**
     * @notice ETH transfer using call
     * @param _to withdrawal destination
     * @param _amount amount to transfer in wei
     * @dev revert if transfer fails
     */
    function _transferEth(address _to, uint256 _amount) private {
        (bool success, bytes memory err) = _to.call{value: _amount}("");
        if (!success) revert TransactionFailed(err);
    }

    /**
     * @notice Query a user's account balance
     * @param _user address to query
     * @return balance account balance in wei for _user
     */
    function getVaultBalance(address _user) external view returns (uint256 balance) {
        return s_vaults[_user];
    }
}

