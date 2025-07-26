// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IBlockchainVerifier {
    function verifyTransaction(bytes32 txHash, address token, address recipient, uint256 amount) external view returns (bool);
}

/**
 * @title SolanaVerifier
 * @dev Contract that verifies Solana USDT (SPL token) transactions
 */
contract SolanaVerifier is IBlockchainVerifier {
    // Owner and oracle addresses
    address private owner;
    address private oracleAddress;
    
    // Structure for Solana transaction data
    struct SolanaTransaction {
        bool exists;
        bytes32 signature;       // Solana transaction signature (hash)
        bytes32 sourceAccount;   // Source wallet address (converted to bytes32)
        bytes32 destinationAccount; // Destination wallet address (converted to bytes32)
        bytes32 mint;            // Token mint address (converted to bytes32)
        uint64 amount;           // Transfer amount (in lamports/smallest unit)
        uint64 slot;             // Solana block slot when transaction was processed
        uint64 timestamp;        // Unix timestamp of the transaction
        bool success;            // Whether the transaction was successful
    }
    
    // Mapping from transaction hash to Solana transaction data
    mapping(bytes32 => SolanaTransaction) private solanaTransactions;
    
    // Mapping from Solana token mint (in bytes32) to Ethereum-compatible address
    mapping(bytes32 => address) private mintToEthAddress;
    
    // Mapping from Solana wallet address (in bytes32) to Ethereum-compatible address
    mapping(bytes32 => address) private solanaToEthAddress;
    
    // Events
    event TransactionAdded(bytes32 indexed txHash, bytes32 indexed sourceAccount, bytes32 indexed destinationAccount, uint64 amount);
    event TokenMappingAdded(bytes32 indexed solanaMint, address indexed ethAddress);
    event AddressMappingAdded(bytes32 indexed solanaAddress, address indexed ethAddress);
    
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
     * @dev Add a mapping between a Solana token mint and an Ethereum-compatible address
     * @param solanaMint Solana token mint as bytes32
     * @param ethAddress Ethereum-compatible address
     */
    function addTokenMapping(bytes32 solanaMint, address ethAddress) external onlyOwner {
        require(solanaMint != bytes32(0), "Invalid Solana mint");
        require(ethAddress != address(0), "Invalid Ethereum address");
        
        mintToEthAddress[solanaMint] = ethAddress;
        
        emit TokenMappingAdded(solanaMint, ethAddress);
    }
    
    /**
     * @dev Add a mapping between a Solana wallet address and an Ethereum-compatible address
     * @param solanaAddress Solana wallet address as bytes32
     * @param ethAddress Ethereum-compatible address
     */
    function addAddressMapping(bytes32 solanaAddress, address ethAddress) external onlyOwner {
        require(solanaAddress != bytes32(0), "Invalid Solana address");
        require(ethAddress != address(0), "Invalid Ethereum address");
        
        solanaToEthAddress[solanaAddress] = ethAddress;
        
        emit AddressMappingAdded(solanaAddress, ethAddress);
    }
    
    /**
     * @dev Add Solana transaction data to the contract (called by the oracle)
     * @param txHash Transaction hash (as used in the DepositHelper contract)
     * @param signature Solana transaction signature as bytes32
     * @param sourceAccount Source wallet address as bytes32
     * @param destinationAccount Destination wallet address as bytes32
     * @param mint Token mint address as bytes32
     * @param amount Transfer amount in lamports/smallest unit
     * @param slot Solana block slot
     * @param timestamp Unix timestamp
     * @param success Whether the transaction was successful
     */
    function addSolanaTransaction(
        bytes32 txHash,
        bytes32 signature,
        bytes32 sourceAccount,
        bytes32 destinationAccount,
        bytes32 mint,
        uint64 amount,
        uint64 slot,
        uint64 timestamp,
        bool success
    ) external onlyOracle {
        require(!solanaTransactions[txHash].exists, "Transaction already exists");
        
        SolanaTransaction storage tx = solanaTransactions[txHash];
        tx.exists = true;
        tx.signature = signature;
        tx.sourceAccount = sourceAccount;
        tx.destinationAccount = destinationAccount;
        tx.mint = mint;
        tx.amount = amount;
        tx.slot = slot;
        tx.timestamp = timestamp;
        tx.success = success;
        
        emit TransactionAdded(txHash, sourceAccount, destinationAccount, amount);
    }
    
    /**
     * @dev Verify a transaction meets the requirements
     * @param txHash Transaction hash (as used in the DepositHelper contract)
     * @param token Ethereum-compatible token address to verify
     * @param recipient Ethereum-compatible recipient address
     * @param amount Expected token amount (in wei equivalent)
     * @return Whether the transaction is valid
     */
    function verifyTransaction(
        bytes32 txHash,
        address token,
        address recipient,
        uint256 amount
    ) external view override returns (bool) {
        SolanaTransaction storage tx = solanaTransactions[txHash];
        
        // Check if transaction exists and was successful
        if (!tx.exists || !tx.success) {
            return false;
        }
        
        // Get the corresponding Ethereum-compatible addresses
        address mappedToken = mintToEthAddress[tx.mint];
        address mappedRecipient = solanaToEthAddress[tx.destinationAccount];
        
        // Verify token and recipient match expected values
        if (mappedToken != token || mappedRecipient != recipient) {
            return false;
        }
        
        // Convert amount to Solana's smallest unit if needed
        // Assuming 6 decimals for USDT and that amount is provided in wei (10^18)
        // Need to divide by 10^12 to get the equivalent in Solana's smallest unit (10^6)
        uint64 expectedAmountInLamports = uint64(amount / 1e12);
        
        // Verify the amount matches or exceeds expected
        return tx.amount >= expectedAmountInLamports;
    }
    
    /**
     * @dev Get Solana transaction details
     * @param txHash Transaction hash
     * @return exists Whether the transaction exists
     * @return signature Solana transaction signature
     * @return sourceAccount Source wallet address
     * @return destinationAccount Destination wallet address
     * @return mint Token mint address
     * @return amount Transfer amount
     * @return slot Solana block slot
     * @return timestamp Unix timestamp
     * @return success Whether the transaction was successful
     */
    function getSolanaTransaction(bytes32 txHash) external view returns (
        bool exists,
        bytes32 signature,
        bytes32 sourceAccount,
        bytes32 destinationAccount,
        bytes32 mint,
        uint64 amount,
        uint64 slot,
        uint64 timestamp,
        bool success
    ) {
        SolanaTransaction storage tx = solanaTransactions[txHash];
        return (
            tx.exists,
            tx.signature,
            tx.sourceAccount,
            tx.destinationAccount,
            tx.mint,
            tx.amount,
            tx.slot,
            tx.timestamp,
            tx.success
        );
    }
    
    /**
     * @dev Get the Ethereum-compatible address for a Solana token mint
     * @param solanaMint Solana token mint as bytes32
     * @return The corresponding Ethereum-compatible address
     */
    function getTokenAddress(bytes32 solanaMint) external view returns (address) {
        return mintToEthAddress[solanaMint];
    }
    
    /**
     * @dev Get the Ethereum-compatible address for a Solana wallet address
     * @param solanaAddress Solana wallet address as bytes32
     * @return The corresponding Ethereum-compatible address
     */
    function getEthereumAddress(bytes32 solanaAddress) external view returns (address) {
        return solanaToEthAddress[solanaAddress];
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