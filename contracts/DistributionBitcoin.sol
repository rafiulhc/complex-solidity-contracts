// SPDX-License-Identifier: None
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract DistributionBitcoin is Ownable {
    // Contract handles
    IERC20 public BEDROCK;
    IERC20 public WBTC;

    // Stake parameters
    address[] public stakerWallets;
    mapping(address => uint256) stakerWalletIndices;
    mapping(address => uint256) public rockStakes;
    mapping(address => uint256) public unclaimedRock;

    // Fee mechanics
    uint8 depositFeePercent = 10;
    uint8 withdrawalFeePercent = 10;
    uint8 burnCutPercent = 50;
    uint8 paybackPercent = 25;
    uint8 treasuryPercent = 25;

    // External wallets
    address public burnWallet;
    address public treasuryWallet;
    address public moderatorWallet;

    // Modifiers
    modifier onlyModerator {
        require(_msgSender() == moderatorWallet, "Access forbidden!");
        _;
    }

    // Events
    event RockStaked(address wallet, uint256 amountDeposited, uint256 effectiveRockStaked);
    event RockUnstaked(address wallet, uint256 amountUnstaked, uint256 effectiveRockUnstaked);

    constructor(address _bedrock, address _wbtc) {
        BEDROCK = IERC20(_bedrock);
        WBTC = IERC20(_wbtc);

        stakerWallets.push(burnWallet);
        burnWallet = 0x000000000000000000000000000000000000dEaD;
        treasuryWallet = _msgSender();
        moderatorWallet = _msgSender();
    }

    // Moderation functions
    function setFeeMechanics(uint8 _depositFeePercent, uint8 _withdrawalFeePercent, uint8 _burnCutPercent, uint8 _paybackPercent, uint8 _treasuryPercent) external onlyOwner {
        depositFeePercent = _depositFeePercent;
        withdrawalFeePercent = _withdrawalFeePercent;
        burnCutPercent = _burnCutPercent;
        paybackPercent = _paybackPercent;
        treasuryPercent = _treasuryPercent;
    }

    function setExternalWallets(address _burnWallet, address _treasuryWallet, address _moderatorWallet) external onlyOwner {
        burnWallet = _burnWallet;
        treasuryWallet = _treasuryWallet;
        moderatorWallet = _moderatorWallet;
    }

    function pullRock(uint256 amount) external onlyOwner {
        BEDROCK.transfer(_msgSender(), amount);
    }

    function pullBitcoin(uint256 amount) external onlyOwner {
        WBTC.transfer(_msgSender(), amount);
    }

    // Staking functions
    function stakeRock(uint256 amount) external {
        if (stakerWalletIndices[_msgSender()] == 0) {
            stakerWalletIndices[_msgSender()] = stakerWallets.length;
            stakerWallets.push(_msgSender());
        }

        uint256 remainingAmount = _deductFee(amount, true);
        rockStakes[_msgSender()] += remainingAmount;
        BEDROCK.transferFrom(_msgSender(), address(this), amount);

        emit RockStaked(_msgSender(), amount, remainingAmount);
    }

    function claimBitcoin(address recipient, uint256 amount) external onlyModerator {
        WBTC.transfer(recipient, amount);
    }

    function claimRock() external {
        uint256 unclaimedAmount = unclaimedRock[_msgSender()];
        require(unclaimedAmount > 0, "You do not have any unclaimed rock left.");
        unclaimedRock[_msgSender()] = 0;
        BEDROCK.transfer(_msgSender(), unclaimedAmount);
    }

    function withdrawRock(uint256 amount) external {
        require(amount <= rockStakes[_msgSender()], "You don't have enough staked");

        if (amount == rockStakes[_msgSender()]) {
            stakerWallets[stakerWalletIndices[_msgSender()]] = stakerWallets[stakerWallets.length - 1];
            stakerWalletIndices[stakerWallets[stakerWallets.length - 1]] = stakerWalletIndices[_msgSender()];
            delete stakerWallets[stakerWallets.length - 1];
            stakerWalletIndices[_msgSender()] = 0;
        }

        uint256 remainingAmount = _deductFee(amount, false);
        rockStakes[_msgSender()] -= amount;
        BEDROCK.transfer(_msgSender(), remainingAmount);

        emit RockUnstaked(_msgSender(), amount, remainingAmount);
    }

    // Utility functions
    function calculateFee(uint256 amount, bool isDeposit) public view returns(uint256 baseFeeAmount, uint256 burnAmount, uint256 paybackAmount, uint256 treasuryAmount) {
        uint8 baseFeePercent = depositFeePercent;
        if (!isDeposit) {
            baseFeePercent = withdrawalFeePercent;
        }

        baseFeeAmount = (amount * baseFeePercent) / 100;
        burnAmount = (baseFeeAmount * burnCutPercent) / 100;
        paybackAmount = (baseFeeAmount * paybackPercent) / 100;
        treasuryAmount = (baseFeeAmount * treasuryPercent) / 100;
    }

    function _deductFee(uint256 amount, bool isDeposit) internal returns(uint256 remainingAmount) {
        (, uint256 burnAmount, uint256 paybackAmount, uint256 treasuryAmount) = calculateFee(amount, isDeposit);

        BEDROCK.transfer(burnWallet, burnAmount);
        BEDROCK.transfer(treasuryWallet, treasuryAmount);

        uint256 slack = _distributeRock(paybackAmount);

        remainingAmount = amount - burnAmount - paybackAmount - treasuryAmount + slack;
    }

    function _distributeRock(uint256 amount) internal returns(uint256 slack) {
        slack = amount;
        for (uint256 i = 0; i < stakerWallets.length; i++) {
            address wallet = stakerWallets[i];
            if (rockStakes[wallet] == 0 || wallet == burnWallet || wallet == address(0) || wallet == _msgSender()) {
                continue;
            }

            uint256 contractRockBalance = BEDROCK.balanceOf(address(this));
            uint256 percentageShare = (100 * rockStakes[wallet]) / contractRockBalance;
            uint256 amountToReward = (amount * percentageShare) / 100;
            unclaimedRock[wallet] += amountToReward;
            slack -= amountToReward;
        }
    }
}