// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TNFT is ERC721 {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 private tokenIds;
    uint256 public nftValue;
    address public stakingManagerContractAddress;

    mapping(uint256 => uint256) public validatorToId;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor() ERC721("Transferrable NFT", "TNFT") {
        nftValue = 0.03 ether;
        stakingManagerContractAddress = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Function only allows the deposit contract to mint to prevent
    //standard eoa minting themselves NFTs
    function mint(address _reciever, uint256 _validatorId) external onlyStakingManagerContract {
        _safeMint(_reciever, tokenIds);
                
        validatorToId[_validatorId] = tokenIds;

        unchecked {
            tokenIds++;
        }

    }

    function getNftId(uint256 _validatorId) public returns (uint256) {
        return validatorToId[_validatorId];
    }

    //--------------------------------------------------------------------------------------
    //-----------------------------------  MODIFIERS  --------------------------------------
    //--------------------------------------------------------------------------------------

    modifier onlyStakingManagerContract() {
        require(
            msg.sender == stakingManagerContractAddress,
            "Only deposit contract function"
        );
        _;
    }
}