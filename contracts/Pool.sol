pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
// import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuasarToken.sol";

/// @title Quasar: capital pool that facilitates mutual-like risk sharing 
/// @author Nikita S. Buzov
/// @notice This contract lets liquidity (coverage) providers to
///         deposit funds and earn fees + native token rewards,
///         while users can buy coverage against the pool
contract Pool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    QuasarToken public rewardsToken; // native token for rewards
    bool private stopped = false; // circuit breaker

    // rewards distribution variables / dictionaries :
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 60 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerEthStored;
    mapping(address => uint256) public userRewardPerEthPaid;
    mapping(address => uint256) public rewards;

    // coverage plan variables:
    uint256 public coveragePrice; // price as percentage of ETH amount covered for 365 days
    uint256 public coverCount; // id number is simply a count
    uint256 public mcr; // Minimum Capital Requirement (pool must be able to cover all possible claims)
    uint256 public availableCapital; // how much of coverage can the pool deliver, equals to (pool - mcr)

    mapping (address => Coverage) public coverageOf; // assign address to the purchased coverage plan
    mapping (uint256 => bool)  public openClaims; // track open claims
    mapping (uint256 => address) public buyerOf; // mapping of a coverage plan id to the user
    struct Coverage {
        uint256 id;
        uint256 expirationTime;
        uint256 coverAmount;
    }

    // capital pool variables:
    uint256 public _totalSupply; // capital pool balance (amount of ETH this contract has)
    mapping(address => uint256) private _balances; // balances of coverage (i.e. liquidity) providers

    /* ========== CONSTRUCTOR ========== */

    constructor() public {
        rewardsToken = new QuasarToken();           // assign new token as the rewards token
        rewardsToken.mint(address(this),1000000);   // mint 1000000 QSR to this contract
        notifyRewardAmount(1000000);                // allocate all the tokens for reward distribution
        coverCount = 0;
        coveragePrice = 2;                          // this set the cover price to 2%
        mcr = 0;
        availableCapital = 0;
    }

    /* ========== VIEWS ========== */

    /// @notice View the total supply of ETH deposited into this contract
    /// @return Amount in Wei
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @notice View the ETH balance of the capital provider account
    /// @param account that deposited ETH
    /// @return Balance in Wei
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @notice View the last time the QSR rewards were applied
    /// @return the UNIX timestamp
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /// @notice View the QSR reward amount per ETH deposited
    /// @return Amount in QSR tokens
    function rewardPerEth() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerEthStored;
        }
        return
            rewardPerEthStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    /// @notice View the earned QSR rewards
    /// @param account that earned the rewards
    /// @return the QSR balance of the account
    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerEth().sub(userRewardPerEthPaid[account])).div(1e18).add(rewards[account]);
    }

    /// @notice View the total amount of rewards
    /// @return amount of QSR rewards for the full distribution period
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /// @notice Purchase coverage for specified ETH amount and time period
    /// @dev This function call must be made with an ETH payment in the amount of `coveragePrice`% / year
    /// @param _coverPeriod Period for which the coverage plan is active (in units of seconds)
    /// @param _coverAmount Amount of ETH to be covered by the plan (in units of Wei)
    /// @return true / false based on success of the function call
    function buyCoverage(uint256 _coverPeriod, uint256 _coverAmount)
        external payable
        stopInEmergency
        paidEnough(_coverAmount.mul(coveragePrice).mul(_coverPeriod).div(100).div(31536000))
        validPeriod(_coverPeriod)
        coverAvailable(_coverAmount)
        returns(bool)
    {
        coverageOf[msg.sender].id = coverCount;
        coverageOf[msg.sender].expirationTime = now.add(_coverPeriod);
        coverageOf[msg.sender].coverAmount = _coverAmount;
        buyerOf[coverCount] = msg.sender;
        coverCount++;
        mcr = mcr.add(_coverAmount);
        availableCapital = _totalSupply.sub(mcr);
        emit CoverPurchased(msg.sender,_coverPeriod,_coverAmount);
        return true;
    }

    /// @notice Deposit ETH to become coverage (liquidity) provider
    /// @dev This function call should be made with an ETH payment in any amount, no parameters
    function deposit()
        external payable
        nonReentrant
        stopInEmergency
        updateReward(msg.sender)
    {
        require(msg.value > 0, "Cannot deposit 0");
        _totalSupply = _totalSupply.add(msg.value);
        _balances[msg.sender] = _balances[msg.sender].add(msg.value);
        availableCapital = _totalSupply.sub(mcr);
        emit Deposited(msg.sender,msg.value);
    }

    /// @notice Withdraw ETH if you are a coverage (liquidity) provider
    /// @dev If you would like to withdraw all the funds, then just call exit() function
    /// @param amount Amount of ETH to be withdrawn (in units of Wei)
    function withdraw(uint256 amount)
        public
        nonReentrant
        stopInEmergency
        isProvider(msg.sender)
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        require(amount <= _balances[msg.sender], "Cannot withdraw more than you deposited");
        (bool success, ) = msg.sender.call{value:amount}("");
        if (success) {
            _totalSupply = _totalSupply.sub(amount);
            _balances[msg.sender] = _balances[msg.sender].sub(amount);
            emit Withdrawn(msg.sender, amount);
        }
        
    }

    /// @notice Claim QSR rewards if you're providing capital
    /// @dev In this version the rewards distribution doesn't seem to work, though the function calls are successful
    function getReward()
        public
        nonReentrant
        stopInEmergency
        updateReward(msg.sender)
    {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /// @notice Withdraw all ETH and all QSR rewards if you are a coverage (liquidity) provider
    function exit()
        external
    {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /// @notice Open claim if you own a plan and something happend
    /// @dev This function call simply sends a message to the contract owner and creates and open claim
    /// @param statement Message to the contract owner with a statement
    function openClaim(string calldata statement)
        external
        validCover(msg.sender)
        claimNotOpen(msg.sender)
    {
        openClaims[coverageOf[msg.sender].id] = true;
        emit ClaimOpened(msg.sender, coverageOf[msg.sender].id, statement);
    }



    /* ========== RESTRICTED FUNCTIONS ========== */

    /// @notice Resolves claim and sends a payout if the claim is valid
    /// @param coverageID The coverage ID number of the claim to be resolved by the contract owner
    /// @param decision Owner's decision for the claim
    function resolveClaim(uint256 coverageID, bool decision)
        public
        onlyOwner
        nonReentrant
        claimOpen(coverageID)
    {
        openClaims[coverageID] = false;
        if (decision == true) {
            address payoutReceiver = buyerOf[coverageID];
            uint256 payoutAmount = coverageOf[payoutReceiver].coverAmount;
            (bool success, ) = payoutReceiver.call{value:payoutAmount}("");
            if (success) {
                emit ClaimPayedOut(coverageID);
            }
        }
        emit ClaimResolved(coverageID, decision);
    }

    /// @notice Sets the coverage price
    /// @param _coveragePrice The coverage price as percentage of ETH amount covered for 365 days
    function setCoveragePrice(uint256 _coveragePrice)
        public
        onlyOwner
    {
        coveragePrice = _coveragePrice; //set in percents, e.g. coverPrice = 2 means that the yearly price is 2% of the principal
        emit CoverPriceUpdated(coveragePrice);
    }

    /// @notice Circuit breaker, pauses the contract capital flows
    /// @dev Contract owner can turn off all ETH and QSR capital flows from/to this contract
    function toggleContractActive()
        public
        onlyOwner
    {
        stopped = !stopped;
    }


    /// @notice Allocates the minted QSR tokens as reward
    /// @param reward Number of reward tokens
    function notifyRewardAmount(uint256 reward)
        internal
        updateReward(address(0))
    {
        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(rewardsDuration);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(rewardsDuration);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint balance = rewardsToken.balanceOf(address(this));
        require(rewardRate <= balance.div(rewardsDuration), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
        emit RewardAdded(reward);
    }

    /* ========== MODIFIERS ========== */

    modifier updateReward(address account) {
        rewardPerEthStored = rewardPerEth();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerEthPaid[account] = rewardPerEthStored;
        }
        _;
    }
    modifier paidEnough(uint256 _price) { require(msg.value >= _price); _;}
    modifier validPeriod(uint256 _period) {require(_period >= 1209600 && _period <= 31536000); _;}
    modifier coverAvailable(uint256 _coverAmount) {require(_coverAmount <= availableCapital); _;}
    modifier validCover(address _buyer) {require(coverageOf[_buyer].expirationTime >= now); _;}
    modifier claimOpen(uint256 _coverageID) {require(openClaims[_coverageID] == true); _;}
    modifier claimNotOpen(address _buyer) {require(openClaims[coverageOf[_buyer].id] != true); _;}
    modifier isProvider(address _provider) {require(_balances[_provider] > 0); _;}
    modifier stopInEmergency { if (!stopped) _; }


    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Deposited(address indexed provider, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event CoverPurchased(address indexed buyer, uint256 period, uint256 amount);
    event CoverPriceUpdated(uint256 newPrice);
    event ClaimOpened(address indexed buyer, uint256 coverageID, string statement);
    event ClaimPayedOut(uint256 coverageID);
    event ClaimResolved(uint256 coverageID, bool decision);
}
