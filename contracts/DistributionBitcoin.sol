// SPDX-License-Identifier: None
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

contract RockBitcoin is Ownable, ReentrancyGuard {
    // Contract handles
    IERC20 public BEDROCK;
    IERC20 public WBTC;

    // BTC Drip variables
    uint8 public WBTCRewardsPercentageFactor = 100; // owner will decide how much WBTC held by this contract and change this variable thereafter
    uint256 public bitcoinDripInterval = 60;  // actual drip interval determined by the owner e.g 60 seconds * 60 minutes * 24 hours
    uint256 public bitcoinDripLastReleaseTime = block.timestamp;
    uint256 public unclaimedBTCDripTotal;

    // Stake parameters
    address[] public stakerWallets;
    mapping(address => uint256) stakerWalletIndices;
    mapping(address => uint256) public rockStakes;
    mapping(address => uint256) public unclaimedRock;
    mapping(address => uint256) public unclaimedBTC;
    mapping(address => uint256) public rollCount;

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
        require(_msgSender() == moderatorWallet, "Access forbidden!, you're not moderator");
        _;
    }

    // Events
    event RockStaked(address wallet, uint256 amountDeposited, uint256 effectiveRockStaked);
    event RockUnstaked(address wallet, uint256 amountUnstaked, uint256 effectiveRockUnstaked);
    event RockRolled(address wallet, uint256 amountRolled, uint256 effectiveRockStaked);

    fallback() external payable {
        // Do nothing
    }

    receive() external payable {
        // Do nothing
    }

    constructor(address _bedrock, address _wbtc){
        BEDROCK = IERC20(_bedrock);
        WBTC = IERC20(_wbtc);

        stakerWallets.push(burnWallet);
        burnWallet = 0x000000000000000000000000000000000000dEaD;
        treasuryWallet = _msgSender();
        moderatorWallet = _msgSender();
    }

    // Total Bedrock balance by the user
    function getUserRockTokens() public view returns (uint256) {
        return BEDROCK.balanceOf(msg.sender);
    }

    // staked Bedrock by the user
    function getUserStakedRockTokens() public view returns (uint256) {
        return rockStakes[msg.sender];
    }

    // unclaimed rock dividends of staker
    function getUserUnclaimedRockDividends() public view returns (uint256) {
        return unclaimedRock[msg.sender];
    }

    // unclaimed BTC dividends of staker
    function getUserUnclaimedBTCDividends() public view returns (uint256) {
        return unclaimedBTC[msg.sender];
    }

    // count how many times user Rolled rock dividends
    function getUserRollCount() public view returns (uint256) {
        return rollCount[msg.sender];
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

    // setter function for BTCRewardsPercentageFactor
    function setBTCRewardsPercentageFactor(uint8 _WBTCRewardsPercentageFactor) external onlyOwner {
        WBTCRewardsPercentageFactor = _WBTCRewardsPercentageFactor;
    }

    // incase of emergency to withdraw all the Rock from this contract
    function pullRock(uint256 amount) external onlyOwner {
        BEDROCK.transfer(_msgSender(), amount);
    }

    // incase of emergency to withdraw all the BTC from this contract
    function pullBitcoin(uint256 amount) external onlyOwner {
        WBTC.transfer(_msgSender(), amount);
    }

    // set Bitcoindrip interval in seconds
    function setBitcoinDripInterval(uint256 _bitcoinDripInterval) external onlyOwner {
        bitcoinDripInterval = _bitcoinDripInterval;
    }

    // Staking functions
    function stakeRock(uint256 amount) public {
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

    // claim unclaimed rock dividends
    function claimRock() external nonReentrant {
        uint256 unclaimedAmount = unclaimedRock[_msgSender()];
        require(unclaimedAmount > 0, "You do not have any unclaimed rock left.");
        unclaimedRock[_msgSender()] = 0;
        BEDROCK.transfer(_msgSender(), unclaimedAmount);
    }

    // approve Bitcoindrip contract by Bedrock contract to spend by user
    function approveBTCB(uint256 _amount) external {
        BEDROCK.approve(address(this), _amount);
    }

    // Roll the unclaimed rock
    function reInvestRock() external nonReentrant {
        uint256 unclaimedAmount = unclaimedRock[_msgSender()];
        require(unclaimedAmount > 0, "You do not have any unclaimed rock left.");
        uint256 remainingAmount = _deductFee(unclaimedAmount, true);
        unclaimedRock[_msgSender()] = 0;
        rockStakes[_msgSender()] += remainingAmount;
        rollCount[_msgSender()]++;

        emit RockRolled(_msgSender(), remainingAmount, remainingAmount);
    }

    function withdrawRock(uint256 amount) external nonReentrant {
        require(amount <= rockStakes[_msgSender()], "You don't have enough staked");

        if (amount == rockStakes[_msgSender()]) {
            stakerWallets[stakerWalletIndices[_msgSender()]] = stakerWallets[stakerWallets.length - 1];
            stakerWalletIndices[stakerWallets[stakerWallets.length - 1]] = stakerWalletIndices[_msgSender()];
            delete stakerWallets[stakerWallets.length - 1];
            stakerWalletIndices[_msgSender()] = 0;
        }

        uint256 remainingAmount = _deductFee(amount, false);
        rockStakes[_msgSender()] -= amount;
        BEDROCK.approve(_msgSender(), amount);
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

    function _distributeRock(uint256 amount) internal returns (uint256 slack) {
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

    // Distribution of Bitcoin Drip
    function distributeBitcoin() external {
        require(block.timestamp > bitcoinDripLastReleaseTime + bitcoinDripInterval, "Bitcoin drip is not ready to be distributed yet.");
        // Calculate the percentage of each staker's stake
        for (uint256 i = 0; i < stakerWallets.length; i++) {
            address wallet = stakerWallets[i];
            if (rockStakes[wallet] == 0 || wallet == burnWallet || wallet == address(0)) {
                continue;
            }


            uint256 eligibleWBTCBalance = WBTC.balanceOf(address(this)) - unclaimedBTCDripTotal;
            uint256 dailyDripAmount = eligibleWBTCBalance / WBTCRewardsPercentageFactor;

            uint256 contractRockBalance = BEDROCK.balanceOf(address(this));
            uint256 percentageShare = (100 * rockStakes[wallet]) / contractRockBalance;
            uint256 dripReward = (dailyDripAmount * percentageShare) / 100;
            unclaimedBTC[wallet] += dripReward;
            unclaimedBTCDripTotal += dripReward;
        }
    }

    function claimBTCDrip() external nonReentrant {
        uint256 unclaimedAmount = unclaimedBTC[_msgSender()];
        require(unclaimedAmount > 0, "You do not have any unclaimed BTCB left.");
        unclaimedBTC[_msgSender()] = 0;
        WBTC.transfer(_msgSender(), unclaimedAmount);
        unclaimedBTCDripTotal -= unclaimedAmount;
    }

    function WBTCBalance() public view returns(uint256){
        return WBTC.balanceOf(address(this));
    }

    function ROCKBalance() public view returns(uint256){
        return BEDROCK.balanceOf(address(this));
    }

}