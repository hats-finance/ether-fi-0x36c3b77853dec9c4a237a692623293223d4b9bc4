// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "lib/ERC721A/contracts/ERC721A.sol";

contract TNFT is ERC721A {
    //--------------------------------------------------------------------------------------
    //---------------------------------  STATE-VARIABLES  ----------------------------------
    //--------------------------------------------------------------------------------------

    uint256 private tokenIds;
    uint256 public nftValue;
    address public depositContractAddress;

    mapping(uint256 => uint256) public validatorToId;

    //--------------------------------------------------------------------------------------
    //----------------------------------  CONSTRUCTOR   ------------------------------------
    //--------------------------------------------------------------------------------------

    constructor() ERC721A("Transferrable NFT", "TNFT") {
        nftValue = 0.03 ether;
        depositContractAddress = msg.sender;
    }

    //--------------------------------------------------------------------------------------
    //----------------------------  STATE-CHANGING FUNCTIONS  ------------------------------
    //--------------------------------------------------------------------------------------

    //Function only allows the deposit contract to mint to prevent
    //standard eoa minting themselves NFTs
    function mint(address _reciever, uint256 _validatorId, uint256 _numberOfDeposits) external onlyDepositContract {
        _safeMint(_reciever, _numberOfDeposits);
                
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

    modifier onlyDepositContract() {
        require(
            msg.sender == depositContractAddress,
            "Only deposit contract function"
        );
        _;
    }
}