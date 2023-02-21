// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract EarlyAdopterPool is Ownable {
    using Math for uint256;

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    //User to help reduce points tallies from extremely large numbers due to token decimals
    uint64 public constant SCALE = 10e11;

    uint64 public constant minDeposit = 0.1 ether;
    uint64 public constant maxDeposit = 100 ether;

    //How much the multiplier must increase per day, actually 0.1 but scaled by 100
    uint64 private constant multiplierCoefficient = 10;

    //After a certain time, claiming funds is not allowed and users will need to simply withdraw
    uint256 public claimDeadline;

    //Time when depositing closed and will be used for calculating reards
    uint256 public endTime;

    address private rETH; // 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address private wstETH; // 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private sfrxEth; // 0xac3e018457b222d93114458476f3e3416abbe38f;

    //Future contract which funds will be sent to on claim (Most likely LP)
    address public claimReceiverContract;

    //Status of claims, true means claiming is open
    bool public claimingOpen;

    //Current users last deposit time
    mapping(address => uint256) public depositTimes;

    //user address => token address = balance
    mapping(address => mapping(address => uint256)) public userToErc20Balance;

    //Users ether balance
    mapping(address => uint256) public userToETHBalance;

    //Combination of all a users token balances
    mapping(address => uint256) public totalUserErc20Balance;

    IERC20 rETHInstance;
    IERC20 wstETHInstance;
    IERC20 sfrxEthInstance;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event DepositERC20(address indexed sender, uint256 amount);
    event DepositEth(address indexed sender, uint256 amount);
    event Withdrawn(address indexed sender, uint256 amount);
    event ClaimReceiverContractSet(address indexed receiverAddress);
    event ClaimingOpened(uint256 deadline);
    event Fundsclaimed(
        address indexed user,
        uint256 indexed amount,
        uint256 indexed pointsAccumulated
    );

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Sets state variables needed for future functions
    /// @param _rETH address of the rEth contract to receive
    /// @param _wstEth address of the wstEth contract to receive
    /// @param _sfrxEth address of the sfrxEth contract to receive
    constructor(
        address _rETH,
        address _wstEth,
        address _sfrxEth
    ) {
        rETH = _rETH;
        wstETH = _wstEth;
        sfrxEth = _sfrxEth;

        rETHInstance = IERC20(_rETH);
        wstETHInstance = IERC20(_wstEth);
        sfrxEthInstance = IERC20(_sfrxEth);
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice deposits ERC20 tokens into contract
    /// @dev User must have approved contract before
    /// @param _erc20Contract erc20 token contract being deposited
    /// @param _amount amount of the erc20 token being deposited
    function deposit(address _erc20Contract, uint256 _amount) external {
        require(
            (_erc20Contract == rETH ||
                _erc20Contract == sfrxEth ||
                _erc20Contract == wstETH),
            "Unsupported token"
        );
        require(
            _amount >= minDeposit && _amount <= maxDeposit,
            "Incorrect Deposit Amount"
        );
        require(claimingOpen == false, "Depositing closed");

        depositTimes[msg.sender] = block.timestamp;

        userToErc20Balance[msg.sender][_erc20Contract] += _amount;
        totalUserErc20Balance[msg.sender] += _amount;
        IERC20(_erc20Contract).transferFrom(msg.sender, address(this), _amount);

        emit DepositERC20(msg.sender, _amount);
    }

    /// @notice deposits Ether into contract
    function depositEther() external payable {
        require(
            msg.value >= minDeposit && msg.value <= maxDeposit,
            "Incorrect Deposit Amount"
        );
        require(claimingOpen == false, "Depositing closed");

        depositTimes[msg.sender] = block.timestamp;
        userToETHBalance[msg.sender] += msg.value;

        emit DepositEth(msg.sender, msg.value);
    }

    /// @notice withdraws all funds from pool for the user calling
    /// @dev no points allocated to users who withdraw
    function withdraw() public payable {
        uint256 balance = transferFunds(msg.sender, 0);
        emit Withdrawn(msg.sender, balance);
    }

    /// @notice Transfers users funds to a new contract such as LP
    /// @dev can only call once receiver contract is ready and claiming is open
    function claim() public {
        require(claimingOpen == true, "Claiming not open");
        require(
            claimReceiverContract != address(0),
            "Claiming address not set"
        );
        require(block.timestamp <= claimDeadline, "Claiming is complete");
        require(depositTimes[msg.sender] != 0, "No deposit stored");

        uint256 pointsRewarded = calculateUserPoints(msg.sender);
        uint256 balance = transferFunds(msg.sender, 1);

        emit Fundsclaimed(msg.sender, balance, pointsRewarded);
    }

    /// @notice Sets claiming to be open, to allow users to claim their points
    /// @param _claimDeadline the amount of time in days until claiming will close
    function setClaimingOpen(uint256 _claimDeadline) public onlyOwner {
        claimDeadline = block.timestamp + (_claimDeadline * 86400);
        claimingOpen = true;
        endTime = block.timestamp;

        emit ClaimingOpened(claimDeadline);
    }

    /// @notice Set the contract which will receive claimed funds
    /// @param _receiverContract contract address for where claiming will send the funds
    function setClaimReceiverContract(address _receiverContract)
        public
        onlyOwner
    {
        require(_receiverContract != address(0), "Cannot set as address zero");
        claimReceiverContract = _receiverContract;

        emit ClaimReceiverContractSet(_receiverContract);
    }

    /// @notice Calculates how many points a user currently has owed to them
    /// @return the amount of points a user currently has accumulated
    function calculateUserPoints(address _user) public view returns (uint256) {

        uint256 lengthOfDeposit;
        
        if(claimingOpen == false) {
            lengthOfDeposit = block.timestamp - depositTimes[_user];
        }else {
            lengthOfDeposit = endTime - depositTimes[_user];
        }

        //Variable to store how many milestones (3 days) the user deposit lasted
        uint256 numberOfMultiplierMilestones = lengthOfDeposit / 259200;

        if (numberOfMultiplierMilestones > 10) {
            numberOfMultiplierMilestones = 10;
        } 

        uint256 userMultiplier = numberOfMultiplierMilestones *
                multiplierCoefficient;

        uint256 totalUserBalance = userToETHBalance[_user] +
            totalUserErc20Balance[_user];

        //Formula for calculating points total
        return
            (((Math.sqrt(totalUserBalance) * lengthOfDeposit) / SCALE) *
                userMultiplier) / 100;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  INTERNAL FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Transfers funds to relevant parties and updates data structures
    /// @param _user user who is withdrawing
    /// @param _identifier identifies which contract function called the function
    /// @return balance of the user withdrawing, used for event
    function transferFunds(address _user, uint256 _identifier)
        internal
        returns (uint256)
    {
        uint256 totalUserBalance = msg.sender.balance +
            totalUserErc20Balance[msg.sender];

        uint256 rETHbal = userToErc20Balance[_user][rETH];
        uint256 wstETHbal = userToErc20Balance[_user][wstETH];
        uint256 sfrxEthbal = userToErc20Balance[_user][sfrxEth];
        uint256 ethBalance = userToETHBalance[_user];

        depositTimes[_user] = 0;
        totalUserErc20Balance[msg.sender] = 0;
        userToETHBalance[msg.sender] = 0;
        userToErc20Balance[_user][rETH] = 0;
        userToErc20Balance[_user][wstETH] = 0;
        userToErc20Balance[_user][sfrxEth] = 0;

        address receiver;

        if (_identifier == 0) {
            receiver = _user;
        } else {
            receiver = claimReceiverContract;
        }

        rETHInstance.transfer(receiver, rETHbal);
        wstETHInstance.transfer(receiver, wstETHbal);
        sfrxEthInstance.transfer(receiver, sfrxEthbal);

        (bool sent, ) = receiver.call{value: ethBalance}("");
        require(sent, "Failed to send Ether");

        return totalUserBalance;
    }

    /// @notice Allows ether to be sent to this contract
    receive() external payable {}
}
