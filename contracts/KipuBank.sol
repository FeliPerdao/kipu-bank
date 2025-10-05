// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

/**
 * @title Contrato KipuBank
 * @author FeliPerdao
 * @notice Contrato para almacenamiento de tokens y funciones de retiro/depósito como un banco. 
 *         Hay límites en los retiros por transacción. 
 *         El contrato posee un límite global de depósitos (bankCap) y contabiliza cantidades de depósitos y retiros.
 * @dev Este contrato es solo para propósitos de aprendizaje
 * @custom:security No uses este código en producción
 */

contract KipuBank {

    /*///////////////////////////////////////////
    ================ IMMUTABLES =================
    ///////////////////////////////////////////*/

    uint256 immutable public i_withdrawLimit; // límite por retiro
    uint256 immutable public i_bankCap; // límite del global del banco

    /*///////////////////////////////////////////
    ============= STATE VARIABLES ===============
    ///////////////////////////////////////////*/

    ///@notice mapping que representa las cuentas personales de cada usuario
    mapping(address user => uint256 balance) public s_vaults;

    ///@notice saldo total almacenado en el banco (todas las cuentas de todos los usuarios)
    uint256 public s_totalBalance;

    ///@notice contadores globales de depósitos y retiros exitosos
    uint256 public s_depositCount;
    uint256 public s_withdrawalCount;

    /*///////////////////////////////////////////
    ================= EVENTS ====================
    ///////////////////////////////////////////*/

    ///@notice eventos emitidos a cada depósito o retiro exitoso
    event DepositPerformed(address indexed user, uint256 amount, uint256 newVaultBalance);
    event WithdrawalPerformed(address indexed user, uint256 amount, uint256 newVaultBalance);

    /*///////////////////////////////////////////
    ================= ERRORS ====================
    ///////////////////////////////////////////*/

    ///@notice revert cuando el intento de depósito excede bankCap
    error BankCapExceeded(uint256 attemptedTotal, uint256 bankCap);

    ///@notice revert cuando el retiro solicitado excede el límite por retiro
    error WithdrawalLimitExceeded(uint256 attemptedWithdraw, uint256 limit);

    ///@notice revert cuando el retiro solicitado excede el saldo en cuenta
    error InsufficientFunds(address user, uint256 attemptedWithdraw, uint256 balance);

    ///@notice error por transferencia falla de ETH
    error TransactionFailed(bytes reason);

    ///@notice revert por detección de ataque reentrancy
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
     * @notice Constructor del contrato
     * @param _withdrawLimit límite máximo de retiro por transacción (wei)
     * @param _bankCap límite global de depósitos (wei)
     */
    constructor(uint256 _withdrawLimit, uint256 _bankCap) {
        i_withdrawLimit = _withdrawLimit;
        i_bankCap = _bankCap;
        s_status = _NOT_ENTERED;
    }

    /*///////////////////////////////////////////
    ============= FALLBACK / RECEIVE ============
    ///////////////////////////////////////////*/

///@notice permite recibir ETH directamente y trata el envío como un depósito
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
     * @notice Deposita ETH en la cuenta de "msg.sender"
     * @dev algorithmo checks-effects-interactions; revierte si saldo del banco supera límite
     */
    function deposit() public payable {
        // -- chequeos --
        uint256 newTotalBalance = s_totalBalance + msg.value;
        if (newTotalBalance > i_bankCap) revert BankCapExceeded(newTotalBalance, i_bankCap);

        // -- efectos --
        s_vaults[msg.sender] += msg.value;
        s_totalBalance = newTotalBalance;
        s_depositCount += 1;

        // -- interacciones --
        emit DepositPerformed(msg.sender, msg.value, s_vaults[msg.sender]);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        // -- chequeos --
        if (_amount > i_withdrawLimit) revert WithdrawalLimitExceeded(_amount, i_withdrawLimit);
        
        uint256 vaultBalance = s_vaults[msg.sender];
        if (_amount > vaultBalance) revert InsufficientFunds(msg.sender, _amount, vaultBalance);

        // -- efectos --
        s_vaults[msg.sender] = vaultBalance - _amount;
        s_totalBalance -= _amount;
        s_withdrawalCount += 1;

        // -- interacciones --
        emit WithdrawalPerformed(msg.sender, _amount, s_vaults[msg.sender]);
        _transferEth(msg.sender, _amount);
    }

    /**
     * @notice Transferencia de ETH usando call
     * @param _to Destiono del retiro
     * @param _amount Cantidad a transferir en wei
     * @dev Revertir si falla la transferencia
     */
    function _transferEth(address _to, uint256 _amount) private {
        (bool success, bytes memory err) = _to.call{value: _amount}("");
        if (!success) revert TransactionFailed(err);
    }

    /**
     * @notice Consulta el saldo en cuenta de un usuario
     * @param _user Dirección a consular
     * @return balance Saldo en wei de la cuenta _user
     */
    function getVaultBalance(address _user) external view returns (uint256 balance) {
        return s_vaults[_user];
    }
}

