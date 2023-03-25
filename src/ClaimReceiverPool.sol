// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./interfaces/IWeth.sol";
import "./EarlyAdopterPool.sol";
import "lib/forge-std/src/console.sol";

contract ClaimReceiverPool is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint24 public constant poolFee = 3000;

    // Mainnet Addresses
    // address private immutable rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    // address private immutable wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    // address private immutable sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    // address private immutable cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;

    //Testnet addresses
    address private immutable wEth = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;
    address private immutable rETH;
    address private immutable wstETH;
    address private immutable sfrxETH;
    address private immutable cbETH;

    bool public dataTransferCompleted = false;

    //SwapRouter but Testnet, although address is actually the same
    ISwapRouter constant router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    
    EarlyAdopterPool public adopterPool;

    //Goerli Weth address used for unwrapping ERC20 Weth
    IWETH constant wethContract = IWETH(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    //Used to track how much was deposited incase we need this information later
    //NB: This is not a balance, but a variable holding the amount of the deposit
    mapping(address => mapping(address => uint256)) public userToERC20Deposit;

    //Every users ether balance
    mapping(address => uint256) public etherBalance;

    //The mapping to hold how much ERC20 a user deposited in the EAP, for validation
    mapping(address => mapping(address => uint256))
        public userToERC20DepositEAP;

    //Mapping to hold how much ether a user deposited in the EAP, for validation
    mapping(address => uint256) public etherBalanceEAP;

    //Hodling how many points a user has
    mapping(address => uint256) public userPoints;

    //--------------------------------------------------------------------------------------
    //-------------------------------------  EVENTS  ---------------------------------------
    //--------------------------------------------------------------------------------------

    event TransferCompleted();

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor(
        address _adopterPool,
        address _rEth,
        address _wstEth,
        address _sfrxEth,
        address _cbEth
    ) {
        rETH = _rEth;
        wstETH = _wstEth;
        sfrxETH = _sfrxEth;
        cbETH = _cbEth;

        adopterPool = EarlyAdopterPool(payable(_adopterPool));
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    /// @notice Allows ether to be sent to this contract
    receive() external payable {}

    /// @notice Sets the number of points a user received
    /// @dev Explain to a developer any extra details
    /// @param _user the address of the user receiving the points
    /// @param _points the number of points the user should receive
    function setEarlyAdopterPoolData(
        address _user, 
        uint256 _points, 
        uint256 _etherBalance, 
        uint256 _rEthBal,
        uint256 _wstEthBal,
        uint256 _sfrxEthBal,
        uint256 _cbEthBal
    ) external onlyOwner {
        require(dataTransferCompleted == false, "Transfer of data has already been complete");

        userPoints[_user] = _points;
        etherBalanceEAP[_user] = _etherBalance;
        userToERC20DepositEAP[_user][rETH] = _rEthBal;
        userToERC20DepositEAP[_user][wstETH] = _wstEthBal;
        userToERC20DepositEAP[_user][sfrxETH] = _sfrxEthBal;
        userToERC20DepositEAP[_user][cbETH] = _cbEthBal;
    }

    function completeDataTransfer() external onlyOwner {
        dataTransferCompleted = true;
        emit TransferCompleted();
    }

    /// @notice Allows user to deposit into the conversion pool
    /// @dev The deposit amount must be the same as what they deposited into the EAP
    /// @param _rEthBal balance of the token to be sent in
    /// @param _wstEthBal balance of the token to be sent in
    /// @param _sfrxEthBal balance of the token to be sent in
    /// @param _cbEthBal balance of the token to be sent in
    function deposit(
        uint256 _rEthBal,
        uint256 _wstEthBal,
        uint256 _sfrxEthBal,
        uint256 _cbEthBal
    ) external payable whenNotPaused {
        if (msg.value > 0) {
            require(etherBalance[msg.sender] == 0, "Already Deposited");
            require(
                msg.value == etherBalanceEAP[msg.sender],
                "Incorrect amount"
            );

            etherBalance[msg.sender] += msg.value;
        }

        if (_rEthBal > 0) {
            require(userToERC20Deposit[msg.sender][rETH] == 0, "Already Deposited");
            _ERC20Update(rETH, _rEthBal);
        }

        if (_wstEthBal > 0) {
            require(userToERC20Deposit[msg.sender][wstETH] == 0, "Already Deposited");
            _ERC20Update(wstETH, _wstEthBal);
        }

        if (_sfrxEthBal > 0) {
            require(userToERC20Deposit[msg.sender][sfrxETH] == 0, "Already Deposited");
            _ERC20Update(sfrxETH, _sfrxEthBal);
        }

        if (_cbEthBal > 0) {
            require(userToERC20Deposit[msg.sender][cbETH] == 0, "Already Deposited");
            _ERC20Update(cbETH, _cbEthBal);
        }
    }

    //Pauses the contract
    function pauseContract() external onlyOwner {
        _pause();
    }

    //Unpauses the contract
    function unPauseContract() external onlyOwner {
        _unpause();
    }

    //--------------------------------------------------------------------------------------
    //--------------------------------  INTERNAL FUNCTIONS  --------------------------------
    //--------------------------------------------------------------------------------------

    function _ERC20Update(address _token, uint256 _amount) internal {
        require(_amount == userToERC20DepositEAP[msg.sender][_token]);
        userToERC20Deposit[msg.sender][_token] = _amount;
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

        uint256 amountOut = _swapExactInputSingle(_amount, _token);
        wethContract.withdraw(amountOut);
        etherBalance[msg.sender] += amountOut;
    }

    function _swapExactInputSingle(
        uint256 _amountIn,
        address _tokenIn
    ) internal returns (uint256 amountOut) {
        IERC20(_tokenIn).approve(address(router), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: wEth,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        amountOut = router.exactInputSingle(params);
    }
}
