// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IBlockchainVerifier {
    function verifyTransaction(bytes32 txHash, address token, address recipient, uint256 amount) external view returns (bool);
}

/**
 * @title EthereumVerifier
 * @dev Contract that verifies Ethereum USDT transactions
 */
contract EthereumVerifier is IBlockchainVerifier {
    // RPC endpoint provider
    address private owner;
    address private oracleAddress;
    
    // Transaction receipt storage
    struct TransactionReceipt {
        bool exists;
        address from;
        address to;
        uint256 value;
        bool success;
        mapping(address => uint256) tokenTransfers; // token address => amount
    }
    
    // Mapping of transaction hash to receipt
    mapping(bytes32 => TransactionReceipt) private transactionReceipts;
    
    // Events
    event TransactionReceiptAdded(bytes32 indexed txHash, address indexed from, address indexed to, uint256 value);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyOracle() {
        require(msg.sender == oracleAddress, "Only oracle can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Set the oracle address that will feed transaction data
     * @param _oracleAddress Address of the oracle service
     */
    function setOracleAddress(address _oracleAddress) external onlyOwner {
        require(_oracleAddress != address(0), "Invalid oracle address");
        oracleAddress = _oracleAddress;
    }
    
    /**
     * @dev Feed transaction data to the contract (called by the oracle)
     * @param txHash Transaction hash
     * @param from Sender address
     * @param to Recipient address
     * @param value ETH value transferred
     * @param success Whether the transaction was successful
     * @param token Token address (if it's a token transfer)
     * @param tokenAmount Token amount transferred
     */
    function addTransactionReceipt(
        bytes32 txHash,
        address from,
        address to,
        uint256 value,
        bool success,
        address token,
        uint256 tokenAmount
    ) external onlyOracle {
        require(!transactionReceipts[txHash].exists, "Transaction receipt already exists");
        
        TransactionReceipt storage receipt = transactionReceipts[txHash];
        receipt.exists = true;
        receipt.from = from;
        receipt.to = to;
        receipt.value = value;
        receipt.success = success;
        
        if (token != address(0) && tokenAmount > 0) {
            receipt.tokenTransfers[token] = tokenAmount;
        }
        
        emit TransactionReceiptAdded(txHash, from, to, value);
    }
    
    /**
     * @dev Add a batch of token transfers for a transaction (for complex transactions)
     * @param txHash Transaction hash
     * @param tokens Array of token addresses
     * @param amounts Array of token amounts
     */
    function addTokenTransfers(
        bytes32 txHash,
        address[] calldata tokens,
        uint256[] calldata amounts
    ) external onlyOracle {
        require(transactionReceipts[txHash].exists, "Transaction receipt does not exist");
        require(tokens.length == amounts.length, "Arrays must be the same length");
        
        TransactionReceipt storage receipt = transactionReceipts[txHash];
        for (uint i = 0; i < tokens.length; i++) {
            receipt.tokenTransfers[tokens[i]] = amounts[i];
        }
    }
    
    /**
     * @dev Verify a transaction meets the requirements
     * @param txHash Transaction hash
     * @param token Token address to verify transfer of
     * @param recipient Expected recipient address
     * @param amount Expected token amount
     * @return Whether the transaction is valid
     */
    function verifyTransaction(
        bytes32 txHash,
        address token,
        address recipient,
        uint256 amount
    ) external view override returns (bool) {
        TransactionReceipt storage receipt = transactionReceipts[txHash];
        
        // Check if transaction exists and was successful
        if (!receipt.exists || !receipt.success) {
            return false;
        }
        
        // For token transfers, verify token, recipient, and amount
        if (token != address(0)) {
            // Check if token transfer amount matches or exceeds expected amount
            return (receipt.tokenTransfers[token] >= amount && receipt.to == recipient);
        }
        
        // For ETH transfers, verify recipient and amount
        return (receipt.to == recipient && receipt.value >= amount);
    }
    
    /**
     * @dev Get transaction receipt details
     * @param txHash Transaction hash
     * @return exists Whether the transaction receipt exists
     * @return from Sender address
     * @return to Recipient address
     * @return value ETH value transferred
     * @return success Whether the transaction was successful
     */
    function getTransactionReceipt(bytes32 txHash) external view returns (
        bool exists,
        address from,
        address to,
        uint256 value,
        bool success
    ) {
        TransactionReceipt storage receipt = transactionReceipts[txHash];
        return (
            receipt.exists,
            receipt.from,
            receipt.to,
            receipt.value,
            receipt.success
        );
    }
    
    /**
     * @dev Get token transfer amount for a specific transaction and token
     * @param txHash Transaction hash
     * @param token Token address
     * @return amount Token amount transferred
     */
    function getTokenTransfer(bytes32 txHash, address token) external view returns (uint256 amount) {
        require(transactionReceipts[txHash].exists, "Transaction receipt does not exist");
        return transactionReceipts[txHash].tokenTransfers[token];
    }
    
    /**
     * @dev Transfer ownership of the contract
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
} 