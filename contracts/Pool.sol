pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
// import "openzeppelin-solidity-2.3.0/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./QuasarToken.sol";


contract Pool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    QuasarToken public rewardsToken;
    // rewards distribution
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public rewardsDuration = 60 days;
    uint256 public lastUpdateTime;
    uint256 public rewardPerEthStored;

    mapping(address => uint256) public userRewardPerEthPaid;
    mapping(address => uint256) public rewards;

    // coverage plans
    uint256 public coveragePrice;
    uint256 public coverCount;
    uint256 public mcr; // Minimum Capital Requirement (pool must be able to cover all possible claims)
    uint256 public availableCapital; // how much of coverage can the pool deliver ( = pool - mcr)

    mapping (address => Coverage) public buyers;
    struct Coverage {
        uint256 id;
        uint256 expirationTime;
        uint256 coverAmount;
    }

    // pool balance tracking
    uint256 public _totalSupply; // capital pool balance
    mapping(address => uint256) private _balances; // balances of coverage providers

    /* ========== CONSTRUCTOR ========== */

    constructor() public {
        rewardsToken = new QuasarToken();
        rewardsToken.mint(address(this),1000000);
        notifyRewardAmount(1000000);
        coverCount = 0;
        coveragePrice = 2;
        mcr = 0;
        availableCapital = 0;
    }

    /* ========== VIEWS ========== */

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerEth() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerEthStored;
        }
        return
            rewardPerEthStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerEth().sub(userRewardPerEthPaid[account])).div(1e18).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function buyCoverage(uint256 _coverPeriod, uint256 _coverAmount)
        external payable
        paidEnough(_coverAmount.mul(coveragePrice).mul(_coverPeriod).div(100).div(31536000))
        validPeriod(_coverPeriod)
        coverAvailable(_coverAmount)
        returns(bool)
    {
        buyers[msg.sender].id = coverCount;
        buyers[msg.sender].expirationTime = now.add(_coverPeriod);
        buyers[msg.sender].coverAmount = _coverAmount;
        coverCount++;
        mcr = mcr.add(_coverAmount);
        availableCapital = _totalSupply.sub(mcr);
        emit CoverPurchased(msg.sender,_coverPeriod,_coverAmount);
        return true;
    }

    function deposit()
        external payable
        nonReentrant
        updateReward(msg.sender)
    {
        require(msg.value > 0, "Cannot deposit 0");
        _totalSupply = _totalSupply.add(msg.value);
        _balances[msg.sender] = _balances[msg.sender].add(msg.value);
        availableCapital = _totalSupply.sub(mcr);
        emit Deposited(msg.sender,msg.value);
    }

    function withdraw(uint256 amount)
        public
        nonReentrant
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

    function getReward()
        public
        nonReentrant
        updateReward(msg.sender)
    {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit()
        external
    {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    function openClaim()
        external
        validCover(msg.sender)
        returns (bool)
    {

    }

    function resolveClaim()
        public
        onlyOwner
        returns (bool)
    {
        
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function setCoveragePrice(uint256 _coveragePrice)
        public
        onlyOwner
    {
        coveragePrice = _coveragePrice; //set in percents, e.g. coverPrice = 2 means that the yearly price is 2% of the principal
        emit CoverPriceUpdated(coveragePrice);
    }

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
    modifier validCover(address _buyer) {require(buyers[_buyer].expirationTime >= now); _;}
    modifier isProvider(address _provider) {require(_balances[_provider] > 0); _;}

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Deposited(address indexed provider, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event CoverPurchased(address indexed buyer, uint256 period, uint256 amount);
    event CoverPriceUpdated(uint256 newPrice);
}
