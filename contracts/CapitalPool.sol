pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./QuasarToken.sol";

contract CapitalPool is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // State variables
    uint256 public coveragePrice;
    uint256 public coverCount;
    // uint256 public capitalPool;
    uint256 public mcr;
    uint256 public availableCapital;
    // uint256 allocPoint; // how many allocation points assigned to this pool (100% since it's the only one?)
    uint256 lastRewardBlock;  // Last block number that QSRs distribution occurs.
    uint256 accQuasarPerShare; // Accumulated QSRs per share, times 1e12. See below.
    mapping (address => Coverage) public buyers;
    mapping (address => ProviderInfo) public providers;
    QuasarToken public quasar;  // QSR token
    uint256 public quasarPerBlock;  // QSR tokens created per block
    uint256 public startBlock;  // the block bumber when QSR mining starts

    struct ProviderInfo {
        uint256 amount;     // How much ETH coverage provider has provided
        uint256 rewardDebt; // Reward debt: amount of QSR pending to be distributed
        // pending reward = (user.amount * accQuasarPerShare) - user.rewardDebt
        //
        // When coverage provider deposits or withdraws from the pool the following happens:
        //  1) `accQuasarPerShare` gets updated
        //  2) pending reward gets distributed
        //  3) `amount` gets updated
        //  4) `rewardDebt` gets updated
    }
    struct Coverage {
        uint256 id;
        uint256 expirationTime;
        uint256 coverAmount;
    }


    // Modifiers
    modifier paidEnough(uint256 _price) { require(msg.value >= _price); _;}
    modifier validPeriod(uint256 _period) {require(_period >= 1209600 && _period <= 31536000); _;}
    modifier coverAvailable(uint256 _coverAmount) {require(_coverAmount <= availableCapital); _;}
    modifier validCover(address buyer) {require(buyers[buyer].expirationTime >= now); _;}

    // Events
    event logCoverPurchase(address indexed buyer);
    event logCapitalDeposited(address indexed provider, uint256 amount);
    event logCapitalWithdraw(address indexed provider, uint256 amount);

    constructor(
        // QuasarToken _quasar,
        // uint256 _quasarPerBlock,
        // uint256 _startBlock
    ) public {
        quasar = new QuasarToken();
        quasarPerBlock = 100;
        startBlock = block.number;
        coverCount = 0;
        // capitalPool = 1000;
        coveragePrice = 2;
        mcr = 0;
        availableCapital = 1000;
    }
 
    // Functions
    function setCoveragePrice(uint256 _coveragePrice) public onlyOwner returns(uint256) {
        coveragePrice = _coveragePrice; //set in percents, e.g. coverPrice = 2 means that the yearly price is 2% of the principal
        return coveragePrice;
    }

    function buyCoverage(uint256 _coverPeriod, uint256 _coverAmount)
        external payable
        paidEnough(_coverAmount.mul(coveragePrice).mul(_coverPeriod).div(100).div(31536000))
        validPeriod(_coverPeriod)
        coverAvailable(_coverAmount)
        returns(bool)
    {
        emit logCoverPurchase(msg.sender);
        buyers[msg.sender].id = coverCount;
        buyers[msg.sender].expirationTime = now.add(_coverPeriod);
        buyers[msg.sender].coverAmount = _coverAmount;
        coverCount++;
        mcr = mcr.add(_coverAmount);
        availableCapital = address(this).balance.sub(mcr);
        return true;
    }

    function depositCapital()
        external payable
        returns(bool)
    {
        updatePool();
        emit logCapitalDeposited(msg.sender, msg.value);
        // capitalPool = capitalPool.add(msg.value);
        availableCapital = address(this).balance.sub(mcr);
        if (providers[msg.sender].amount > 0) {
            uint256 pending = providers[msg.sender].amount.mul(accQuasarPerShare).div(1e12).sub(providers[msg.sender].rewardDebt);
            if (pending > 0) {
                quasar.transfer(msg.sender, pending);
            }
            providers[msg.sender].amount = providers[msg.sender].amount.add(msg.value);
        } else{
            providers[msg.sender].amount = msg.value;
            providers[msg.sender].rewardDebt = 0;
        }
        // providers[msg.sender].rewardDebt = providers[msg.sender].amount;
        return true;
    }
    
    // View function to see pending QSRs on frontend.
    function pendingQuasar(address _provider)
        external view
        returns (uint256)
    {
        ProviderInfo storage provider = providers[_provider];
        uint256 poolBalance = address(this).balance;
        uint256 accumulatedQuasarPerShare = accQuasarPerShare;
        if (poolBalance != 0) {
            accumulatedQuasarPerShare = accumulatedQuasarPerShare.add(quasarPerBlock.mul(1e12).div(poolBalance));
        }
        return provider.amount.mul(accumulatedQuasarPerShare).div(1e12).sub(provider.rewardDebt);
    }

    function updatePool()
        public
    {
        if (block.number <= lastRewardBlock) {
            return;
        }
        uint256 poolBalance = address(this).balance;
        if (poolBalance == 0) {
            lastRewardBlock = block.number;
            return;
        }
        // uint256 quasarReward = quasarPerBlock.mul(allocPoint);
        quasar.mint(address(this), quasarPerBlock);
        accQuasarPerShare = accQuasarPerShare.add(quasarPerBlock.mul(1e12).div(poolBalance));
        lastRewardBlock = block.number;
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
    
}