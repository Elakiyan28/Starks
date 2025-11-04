// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Medicochain
 * @dev A smart contract for tracking a medical supply chain.
 * It registers creators (manufacturers) and distributors to ensure
 * only verified parties can create and update medicine batches.
 */
contract Medicochain {

    // --- Roles ---
    address public contractOwner; // The admin of the whole system
    
    // We store the roles of participants
    // A wallet address is mapped to a Role
    enum Role { NONE, CREATOR, DISTRIBUTOR }
    mapping(address => Role) public roles;

    // --- Data Structures ---

    /**
     * @dev Represents a single step in the supply chain.
     */
    struct Transaction {
        address actor;      // Who performed the action (wallet address)
        string action;      // e.g., "MANUFACTURED", "SHIPPED", "RECEIVED"
        string location;    // e.g., "PharmaCo Labs", "Warehouse A"
        uint256 timestamp;  // When it happened
    }

    /**
     * @dev Represents a single batch of medicine.
     */
    struct Product {
        string productId;   // The unique ID from the QR code
        string name;        // e.g., "Aspirin 500mg"
        address creator;    // The manufacturer's wallet address
        uint256 expiryDate; // Expiry date as a timestamp
        bool isInitialized; // To check if a product exists
    }

    // --- State Variables (The Ledger) ---

    // Mapping from a product ID (bytes32) to its Product struct
    // We use bytes32 for the ID because it's cheaper for lookups
    mapping(bytes32 => Product) public products;
    
    // Mapping from a product ID (bytes32) to its array of transactions
    mapping(bytes32 => Transaction[]) public transactionHistory;

    // --- Events ---
    // These log data to the blockchain for our frontend to listen to.
    event RoleGranted(address indexed user, Role indexed role);
    event BatchCreated(bytes32 indexed productId, string name, address indexed creator);
    event TransactionAdded(bytes32 indexed productId, string action, address indexed actor);

    // --- Modifiers (Security Checks) ---

    /**
     * @dev Restricts a function to only be callable by the contract owner.
     */
    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only owner can call this");
        _;
    }

    /**
     * @dev Restricts a function to only be callable by a registered Creator.
     */
    modifier onlyCreator() {
        require(roles[msg.sender] == Role.CREATOR, "Only creators can call this");
        _;
    }

    /**
     * @dev Restricts a function to registered Creators OR Distributors.
     */
    modifier canTransact() {
        require(roles[msg.sender] == Role.CREATOR || roles[msg.sender] == Role.DISTRIBUTOR, "Only registered actors can transact");
        _;
    }

    // --- Constructor ---
    /**
     * @dev Sets the contract deployer as the owner.
     */
    constructor() {
        contractOwner = msg.sender;
    }

    // --- Role Management Functions ---

    /**
     * @dev Called by the owner to grant a role to a user.
     * This is how we onboard manufacturers and distributors.
     */
    function grantRole(address _user, Role _role) public onlyOwner {
        require(_role != Role.NONE, "Cannot grant NONE role");
        roles[_user] = _role;
        emit RoleGranted(_user, _role);
    }

    // --- Core Functions ---

    /**
     * @dev Creates a new batch of medicine.
     * Only callable by a CREATOR.
     * This is the "genesis" transaction for a product.
     */
    function createBatch(
        string memory _productId,
        string memory _name,
        uint256 _expiryDate
    ) public onlyCreator {
        // Convert the string ID to bytes32 for mapping
        bytes32 productId = keccak256(abi.encodePacked(_productId));
        
        // Check that this product doesn't already exist
        require(!products[productId].isInitialized, "Product ID already exists");

        // 1. Create the Product
        products[productId] = Product({
            productId: _productId,
            name: _name,
            creator: msg.sender,
            expiryDate: _expiryDate,
            isInitialized: true
        });

        // 2. Create the first "MANUFACTURED" transaction
        addTransactionInternal(productId, "MANUFACTURED", "Creator Facility");

        emit BatchCreated(productId, _name, msg.sender);
    }

    /**
     * @dev Adds a new history step to a product.
     * Only callable by CREATOR or DISTRIBUTOR.
     */
    function addTransaction(
        string memory _productId,
        string memory _action,
        string memory _location
    ) public canTransact {
        bytes32 productId = keccak256(abi.encodePacked(_productId));
        require(products[productId].isInitialized, "Product does not exist");
        
        addTransactionInternal(productId, _action, _location);
    }

    /**
     * @dev Internal function to add a transaction.
     */
    function addTransactionInternal(
        bytes32 _productId, 
        string memory _action, 
        string memory _location
    ) private {
        transactionHistory[_productId].push(Transaction({
            actor: msg.sender,
            action: _action,
            location: _location,
            timestamp: block.timestamp
        }));
        
        emit TransactionAdded(_productId, _action, msg.sender);
    }

    // --- View Functions (Public Read) ---

    /**
     * @dev Gets the core details of a product.
     * Anyone can call this.
     */
    function getProduct(string memory _productId) 
        public 
        view 
        returns (Product memory) 
    {
        bytes32 productId = keccak256(abi.encodePacked(_productId));
        require(products[productId].isInitialized, "Product does not exist");
        return products[productId];
    }

    /**
     * @dev Gets the full transaction history for a product.
     * Anyone can call this.
     */
    function getProductHistory(string memory _productId) 
        public 
        view 
        returns (Transaction[] memory) 
    {
        bytes32 productId = keccak256(abi.encodePacked(_productId));
        return transactionHistory[productId];
    }
}