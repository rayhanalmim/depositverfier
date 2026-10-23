// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interface for USDT ERC20 token
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// Interface to interact with blockchain data
interface IBlockchainVerifier {
    function verifyTransaction(bytes32 txHash, address token, address recipient, uint256 amount) external view returns (bool);
}

contract DepositHelper {
    // USDT token contract addresses for different networks
    address public immutable usdtTokenAddressEth;
    address public immutable usdtTokenAddressBsc;
    address public immutable usdtTokenAddressSol;
    
    // Fixed deposit addresses for USDT on different networks
    address public immutable usdtDepositAddressEth;
    address public immutable usdtDepositAddressBsc;
    address public immutable usdtDepositAddressSol;
    
    // Mapping to track verified transactions
    mapping(bytes32 => bool) public verifiedTransactions;
    
    // Owner of the contract
    address public owner;

    // Network identifiers
    enum Network { ETHEREUM, BSC, SOLANA }

    // Blockchain verifier contracts for different networks
    IBlockchainVerifier public ethVerifier;
    IBlockchainVerifier public bscVerifier;
    IBlockchainVerifier public solVerifier;

    // Events
    event DepositVerified(
        bytes32 indexed transactionHash,
        address indexed tokenAddress,
        uint256 amount,
        uint256 timestamp,
        bool transferStatus,
        Network network
    );
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(
        address _usdtTokenAddressEth, address _usdtDepositAddressEth,
        address _usdtTokenAddressBsc, address _usdtDepositAddressBsc,
        address _usdtTokenAddressSol, address _usdtDepositAddressSol
    ) {
        require(_usdtTokenAddressEth != address(0), "Invalid ETH USDT token address");
        require(_usdtDepositAddressEth != address(0), "Invalid ETH deposit address");
        require(_usdtTokenAddressBsc != address(0), "Invalid BSC USDT token address");
        require(_usdtDepositAddressBsc != address(0), "Invalid BSC deposit address");
        require(_usdtTokenAddressSol != address(0), "Invalid SOL USDT token address");
        require(_usdtDepositAddressSol != address(0), "Invalid SOL deposit address");
        
        usdtTokenAddressEth = _usdtTokenAddressEth;
        usdtDepositAddressEth = _usdtDepositAddressEth;
        
        usdtTokenAddressBsc = _usdtTokenAddressBsc;
        usdtDepositAddressBsc = _usdtDepositAddressBsc;
        
        usdtTokenAddressSol = _usdtTokenAddressSol;
        usdtDepositAddressSol = _usdtDepositAddressSol;
        
        owner = msg.sender;
    }

    /**
     * @dev Get USDT deposit address for Ethereum
     * @return The fixed deposit address for USDT on Ethereum
     */
    function getUsdtDepositAddressEth() external view returns (address) {
        return usdtDepositAddressEth;
    }
    
    /**
     * @dev Get USDT deposit address for BSC
     * @return The fixed deposit address for USDT on BSC
     */
    function getUsdtDepositAddressBsc() external view returns (address) {
        return usdtDepositAddressBsc;
    }
    
    /**
     * @dev Get USDT deposit address for Solana
     * @return The fixed deposit address for USDT on Solana
     */
    function getUsdtDepositAddressSol() external view returns (address) {
        return usdtDepositAddressSol;
    }

    /**
     * @dev Get all USDT deposit addresses
     * @return The fixed deposit addresses for USDT on all networks
     */
    function getAllUsdtDepositAddresses() external view returns (address, address, address) {
        return (usdtDepositAddressEth, usdtDepositAddressBsc, usdtDepositAddressSol);
    }

    /**
     * @dev Set blockchain verifiers for each network
     * @param _ethVerifier Address of the Ethereum verifier
     * @param _bscVerifier Address of the BSC verifier
     * @param _solVerifier Address of the Solana verifier
     */
    function setVerifiers(
        address _ethVerifier, 
        address _bscVerifier, 
        address _solVerifier
    ) external onlyOwner {
        require(_ethVerifier != address(0), "Invalid ETH verifier address");
        require(_bscVerifier != address(0), "Invalid BSC verifier address");
        require(_solVerifier != address(0), "Invalid SOL verifier address");
        
        ethVerifier = IBlockchainVerifier(_ethVerifier);
        bscVerifier = IBlockchainVerifier(_bscVerifier);
        solVerifier = IBlockchainVerifier(_solVerifier);
    }

    /**
     * @dev Verify a deposit transaction by checking blockchain data
     * @param transactionHash The hash of the transaction to verify
     * @param amount The amount of tokens deposited
     * @param network The network identifier (0 = ETH, 1 = BSC, 2 = SOL)
     * @return success Boolean indicating verification success
     */
    function verifyDeposit(bytes32 transactionHash, uint256 amount, Network network) external returns (bool success) {
        require(!verifiedTransactions[transactionHash], "Transaction already verified");
        require(amount > 0, "Amount must be greater than 0");
        
        // Get the token address and deposit address based on the network
        address tokenAddress;
        address depositAddress;
        IBlockchainVerifier verifier;
        
        if (network == Network.ETHEREUM) {
            tokenAddress = usdtTokenAddressEth;
            depositAddress = usdtDepositAddressEth;
            verifier = ethVerifier;
        } else if (network == Network.BSC) {
            tokenAddress = usdtTokenAddressBsc;
            depositAddress = usdtDepositAddressBsc;
            verifier = bscVerifier;
        } else if (network == Network.SOLANA) {
            tokenAddress = usdtTokenAddressSol;
            depositAddress = usdtDepositAddressSol;
            verifier = solVerifier;
        } else {
            revert("Unsupported network");
        }
        
        require(address(verifier) != address(0), "Verifier not set for this network");
        
        // Verify the transaction by checking blockchain data
        bool transferStatus = verifier.verifyTransaction(
            transactionHash,
            tokenAddress,
            depositAddress,
            amount
        );
        
        require(transferStatus, "Transaction verification failed");
        
        // Mark transaction as verified if successful
        verifiedTransactions[transactionHash] = true;
        
        // Emit verification event
        emit DepositVerified(
            transactionHash,
            tokenAddress,
            amount,
            block.timestamp,
            transferStatus,
            network
        );
        
        return transferStatus;
    }

    /**
     * @dev Check if a transaction has been verified
     * @param transactionHash The hash of the transaction to check
     * @return Whether the transaction has been verified
     */
    function isTransactionVerified(bytes32 transactionHash) external view returns (bool) {
        return verifiedTransactions[transactionHash];
    }

    /**
     * @dev Transfer contract ownership
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
} 