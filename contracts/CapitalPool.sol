pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract CapitalPool is Ownable {
    using SafeMath for uint256;

    // State variables
    uint256 public coveragePrice;
    uint256 public coverCount;
    uint256 public capitalPool;
    uint256 public mcr;
    uint256 public availableCapital;
    mapping (address => Coverage) public coverages;
    mapping (address => bool) public providers;
    mapping (address => uint) public balanceOf;

    struct Coverage {
        uint256 id;
        uint256 expirationTime;
        uint256 coverAmount;
    }
    // Modifiers
    modifier paidEnough(uint256 _price) { require(msg.value >= _price); _;}
    modifier validPeriod(uint256 _period) {require(_period >= 1209600 && _period <= 31536000); _;}
    modifier coverAvailable(uint256 _coverAmount) {require(_coverAmount <= availableCapital); _;}

    // Events
    event logCoverPurchase(address indexed buyer);
    event logCapitalDeposited(address indexed provider);

    constructor() public {
        coverCount = 0;
        capitalPool = 1000;
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
        coverages[msg.sender].id = coverCount;
        coverages[msg.sender].expirationTime = now.add(_coverPeriod);
        coverages[msg.sender].coverAmount = _coverAmount;
        coverCount++;
        mcr = mcr.add(_coverAmount);
        availableCapital = capitalPool.sub(mcr);

        return true;
    }

    function depositCapital()
        external payable
        returns(bool)
    {
        emit logCapitalDeposited(msg.sender);
        capitalPool = capitalPool.add(msg.value);
        availableCapital = capitalPool.sub(mcr);
        providers[msg.sender] = true;
        balanceOf[msg.sender] = msg.value;

        return true;
    }

    
}