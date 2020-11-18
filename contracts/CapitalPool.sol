pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract CapitalPool is Ownable {

    // State variables
    uint256 public coveragePrice;
    uint256 public coverCount;
    uint256 public capitalPool;
    uint256 public mcr;
    uint256 public availableCapital;
    mapping (address => Coverage) public coverages;

    struct Coverage {
        uint256 id;
        uint256 expirationTime;
        uint256 coverAmount;
    }
    // Modifiers
    modifier paidEnough(uint _price) { require(msg.value >= _price); _;}
    modifier validPeriod(uint _period) {require(_period >= 1209600 && _period <= 31536000); _;}
    modifier coverAvailable(uint _coverAmount) {require(_coverAmount <= availableCapital); _;}

    // Events
    event logCoverPurchase(address indexed buyer);

    constructor() public {
        coverCount = 0;
        capitalPool = 0;
        coveragePrice = 2;
        mcr = 0;
        availableCapital =0;
    }
 
    // Functions
    function setCoveragePrice(uint256 _coveragePrice) public onlyOwner {
        coveragePrice = _coveragePrice; //set in percents, e.g. coverPrice = 2 means that the yearly price is 2% of the principal
    }

    function buyCoverage(uint256 _coverPeriod, uint256 _coverAmount)
        public payable
        paidEnough(_coverAmount*coveragePrice/100*_coverPeriod/31536000)
        validPeriod(_coverPeriod)
        coverAvailable(_coverAmount)
        returns(bool)
    {
        emit logCoverPurchase(msg.sender);
        coverages[msg.sender].id = coverCount;
        coverages[msg.sender].expirationTime = now + _coverPeriod;
        coverages[msg.sender].coverAmount = _coverAmount;
        coverCount++;
        mcr = mcr + _coverAmount;
        availableCapital = capitalPool - mcr;

        return true;
    }

}