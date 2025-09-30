// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Seed Seller ↔ Farmer Transaction Contract
/// @notice Handles seed purchases using Farmer ID, Farm size, and Seed type.
/// @dev Farmer ID must be hashed off-chain (e.g., keccak256(aadhar)) before passing.

contract SeedSeller {
    address public seller;   // seed seller address (receives payments)

    constructor() {
        seller = msg.sender;
    }

    // Seed Types
    enum SeedType { WHEAT, RICE, MAIZE, COTTON }

    // Farmer details
    struct Farmer {
        bytes32 aadharHash;   // Hashed Aadhar No
        uint256 farmSize;     // Farm size (in acres or hectares)
        bool registered;
    }

    // Purchase details
    struct Purchase {
        bytes32 farmerId;
        SeedType seedType;
        uint256 seedAmount;   // calculated based on farm size
        uint256 amountPaid;
        uint256 timestamp;
    }

    // Storage
    mapping(bytes32 => Farmer) public farmers;          // farmerId => Farmer
    mapping(uint256 => Purchase) public purchases;      // purchaseId => Purchase
    uint256 public nextPurchaseId;

    // Seed price per unit (set by seller)
    mapping(SeedType => uint256) public seedPricePerUnit;

    // Events
    event FarmerRegistered(bytes32 indexed farmerId, uint256 farmSize);
    event SeedsPurchased(uint256 purchaseId, bytes32 indexed farmerId, SeedType seedType, uint256 seedAmount, uint256 paid);

    // ----------------------------
    // Functions
    // ----------------------------

    /// @notice Register a farmer
    function registerFarmer(bytes32 aadharHash, uint256 farmSize) external {
        require(!farmers[aadharHash].registered, "Farmer already registered");
        farmers[aadharHash] = Farmer(aadharHash, farmSize, true);
        emit FarmerRegistered(aadharHash, farmSize);
    }

    /// @notice Set price per seed unit (only seller)
    function setSeedPrice(SeedType seedType, uint256 price) external {
        require(msg.sender == seller, "Only seller");
        seedPricePerUnit[seedType] = price;
    }

    /// @notice Farmer buys seeds (price = farmSize * price per unit)
    function buySeeds(bytes32 farmerId, SeedType seedType) external payable {
        Farmer memory f = farmers[farmerId];
        require(f.registered, "Farmer not registered");

        uint256 unitPrice = seedPricePerUnit[seedType];
        require(unitPrice > 0, "Seed price not set");

        uint256 totalPrice = f.farmSize * unitPrice;
        require(msg.value >= totalPrice, "Not enough payment");

        // record purchase
        purchases[nextPurchaseId] = Purchase({
            farmerId: farmerId,
            seedType: seedType,
            seedAmount: f.farmSize, // 1 unit per farm size (can adjust formula)
            amountPaid: totalPrice,
            timestamp: block.timestamp
        });

        emit SeedsPurchased(nextPurchaseId, farmerId, seedType, f.farmSize, totalPrice);
        nextPurchaseId++;

        // transfer money to seller
        (bool sent, ) = seller.call{value: totalPrice}("");
        require(sent, "Payment failed");

        // refund extra ETH if any
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
    }
}
