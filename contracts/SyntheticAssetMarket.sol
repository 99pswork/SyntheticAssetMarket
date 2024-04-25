// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SyntheticAssetMarket is Ownable {

    struct Position {
        bool isOpen;
        bool isLong;
        uint256 positionSize;
        uint256 averagePrice;
        uint256 profit;
        uint256 loss;
    }

    // ERC20 token used as collateral
    IERC20 public collateralToken;

    // Assume a fixed synthetic asset price for simplicity
     uint256 syntheticAssetPrice = 1000; // $1000 per synthetic asset
     uint256 leverage = 5; // 5x leverage

    // Mapping of user addresses to their collateral balances
    mapping(address => uint256) public collateralBalances;

    // Mapping of user address to their postions 
    mapping(address => Position) public getPosition;

    // Constructor
    constructor(address _collateralToken) Ownable(msg.sender) {
        collateralToken = IERC20(_collateralToken);
    }

    // Function to deposit collateral
    function depositCollateral(uint256 _amount) external {
        
        // Transfer collateral from user to contract
        require(collateralToken.transferFrom(msg.sender, address(this), _amount), "Transfer Failed!");
        
        // Update user's collateral balance
        collateralBalances[msg.sender] += _amount;
    }

    // Function to withdraw collateral
    function withdrawCollateral(uint256 _amount) external {
        // Ensure user has sufficient balance
        require(collateralBalances[msg.sender] >= _amount, "Insufficient balance");
        
        // Update user's collateral balance
        collateralBalances[msg.sender] -= _amount;

        // Transfer collateral from contract to user
        require(collateralToken.transfer(msg.sender, _amount), "Transfer Failed");
    }

    // Function to open a leveraged position
    function openPosition(uint256 _collateralAmount, bool _isLong) external {
        // Get poistion for the address
        Position storage position = getPosition[msg.sender];
        require(!position.isOpen, "Position is already open");
        position.isOpen = true;
        
        // Validate inputs
        require(_collateralAmount <= collateralBalances[msg.sender], "Insufficient collateral");
        
        // Update user's collateral balance
        collateralBalances[msg.sender] -= _collateralAmount;

        // Calculate position size based on collateral amount and leverage
        uint256 positionSize = (_collateralAmount * leverage) / syntheticAssetPrice; // Position size in synthetic assets, also need to take care of decimal adjustment while conversion if any.
        position.positionSize = positionSize;
        position.averagePrice = syntheticAssetPrice;
        position.profit = 0;
        position.loss = 0;
        position.isLong = _isLong;
    }

    function increaseLeverage(uint256 _collateralAmount) external {
        // Get poistion for the address
        Position storage position = getPosition[msg.sender];
        require(position.isOpen, "Position is not open");

        // Validate inputs
        require(_collateralAmount <= collateralBalances[msg.sender], "Insufficient collateral");
        
        // Update user's collateral balance
        collateralBalances[msg.sender] -= _collateralAmount;

        uint256 positionSize = (_collateralAmount * leverage) / syntheticAssetPrice; // Position size in synthetic assets, also need to take care of decimal adjustment while conversion if any.
        uint256 newAveragePrice = (position.positionSize*position.averagePrice + positionSize*syntheticAssetPrice) / (position.positionSize + positionSize);

        position.positionSize += positionSize;
        position.averagePrice = newAveragePrice;
    }

    function reduceLeverage(uint256 positionSize) external {
        // Get poistion for the address
        Position storage position = getPosition[msg.sender];
        require(position.isOpen, "Position is not open");
        
        uint256 collateralReturned = positionSize * syntheticAssetPrice / leverage;
        
        // Update Position
        position.positionSize -= positionSize;

        if(position.isLong){
            if(position.averagePrice > syntheticAssetPrice)
            {
                position.profit += positionSize*(position.averagePrice - syntheticAssetPrice);
                collateralReturned += positionSize*(position.averagePrice - syntheticAssetPrice);
            }
            else{
                position.loss += positionSize*(syntheticAssetPrice - position.averagePrice);
                if(positionSize*(syntheticAssetPrice - position.averagePrice) <= collateralReturned){
                    collateralReturned -= positionSize*(position.averagePrice - syntheticAssetPrice);
                }
                else{
                    // Can have logic for clearning the collateralBalances and clearing other positons if any
                    collateralReturned = 0;
                }
                collateralReturned -= positionSize*(syntheticAssetPrice - position.averagePrice);
            }
        } else {
            if(position.averagePrice > syntheticAssetPrice)
            {
                position.loss += positionSize*(position.averagePrice - syntheticAssetPrice);
                if(positionSize*(position.averagePrice - syntheticAssetPrice) <= collateralReturned){
                    collateralReturned -= positionSize*(position.averagePrice - syntheticAssetPrice);
                }
                else{
                    // Can have logic for clearning the collateralBalances and clearing other positons if any
                    collateralReturned = 0;
                }
                
            }
            else{
                position.profit += positionSize*(syntheticAssetPrice - position.averagePrice);
                collateralReturned += positionSize*(syntheticAssetPrice - position.averagePrice);
            }
        }

        // Update user's collateral balance
        collateralBalances[msg.sender] += collateralReturned;
    }

    function closePosition() external {
        // Get poistion for the address
        Position storage position = getPosition[msg.sender];
        require(position.isOpen, "Position is not open");

        uint256 collateralReturned = position.positionSize * position.averagePrice / leverage;

        if(position.isLong){
            if(position.averagePrice > syntheticAssetPrice)
            {
                position.profit += position.positionSize*(position.averagePrice - syntheticAssetPrice);
                collateralReturned += position.positionSize*(position.averagePrice - syntheticAssetPrice);
            }
            else{
                position.loss += position.positionSize*(syntheticAssetPrice - position.averagePrice);
                if(position.positionSize*(syntheticAssetPrice - position.averagePrice) <= collateralReturned){
                    collateralReturned -= position.positionSize*(position.averagePrice - syntheticAssetPrice);
                }
                else{
                    // Can have logic for clearning the collateralBalances and clearing other positons if any
                    collateralReturned = 0;
                }
                collateralReturned -= position.positionSize*(syntheticAssetPrice - position.averagePrice);
            }
        } else {
            if(position.averagePrice > syntheticAssetPrice)
            {
                position.loss += position.positionSize*(position.averagePrice - syntheticAssetPrice);
                if(position.positionSize*(position.averagePrice - syntheticAssetPrice) <= collateralReturned){
                    collateralReturned -= position.positionSize*(position.averagePrice - syntheticAssetPrice);
                }
                else{
                    // Can have logic for clearning the collateralBalances and clearing other positons if any
                    collateralReturned = 0;
                }
                
            }
            else{
                position.profit += position.positionSize*(syntheticAssetPrice - position.averagePrice);
                collateralReturned += position.positionSize*(syntheticAssetPrice - position.averagePrice);
            }
        }

        // Update Position
        position.positionSize = 0;

        // Update user's collateral balance
        collateralBalances[msg.sender] += collateralReturned;
        position.isOpen = false;
    }

    function updateSyntheticPrice(uint256 _price) external onlyOwner {
        syntheticAssetPrice = _price;
    }
}
