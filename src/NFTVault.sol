// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import {Auth} from "solmate/auth/Auth.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {USDCVault} from "./USDCVault.sol";
import {APIConsumer} from "./APIConsumer.sol";

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract NFTVault is ERC20, Auth {
  using SafeCastLib for uint256;
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /*///////////////////////////////////////////////////////////////
                              IMMUTABLES
  //////////////////////////////////////////////////////////////*/

  ERC721 public immutable UNDERLYING;
  APIConsumer public immutable ORACLE;
  //TODO: put in deployed address
  address public immutable USDCVaultAddress = 0x352ac7fFB92182ce64DC245eb86228EF7B4063b5; 
  uint256 public immutable timeBeforeLiquidation = 365 days;
  
  /*///////////////////////////////////////////////////////////////
                          CONFIGURATION
  //////////////////////////////////////////////////////////////*/

  uint256 public immutable loanToValue;
  uint256 public immutable liquidationPrice;
  // Interest, in decimals.
  uint8 public immutable interest;

  USDCVault public immutable VAULT;
  uint256 internal immutable BASE_UNIT;
  
  constructor(
    ERC721 _UNDERLYING, 
    USDCVault _VAULT,
    APIConsumer _ORACLE,
    uint8 _decimals,
    uint8 _interest
  ) 
    ERC20(
      // Vault name
      string(abi.encodePacked( _UNDERLYING.name(), " Vault")),
      // Vault symbol
      string(abi.encodePacked("v", _UNDERLYING.symbol())),
      // Decimals
      _decimals
    )
    Auth(Auth(msg.sender).owner(), Auth(msg.sender).authority())
  {

    interest = _interest;

    BASE_UNIT = 10**decimals;
    
    UNDERLYING = _UNDERLYING;

    VAULT = _VAULT;

    ORACLE = _ORACLE;
    //Set liquidation price to be 30% of floor price.
    liquidationPrice = ORACLE.floorPrice().mulDivDown(3, 10000);
    //Set loan to value to be 10% of floor price.
    loanToValue = ORACLE.floorPrice().mulDivDown(1, 10000);
  }

  /*///////////////////////////////////////////////////////////////
                              STORAGE
  //////////////////////////////////////////////////////////////*/

  struct loanData {
    // Price of token when it is liquidated.
    uint256 liquidationPrice;
    // Time when tokens can be liquidated.
    uint256 liquidationTime;
    // Amount required to unlock token (loan value + interest).
    uint256 repayAmount;
  }

  // Maps token Id to loan data.
  mapping(uint256 => loanData) private getLoanData;
  
  /*///////////////////////////////////////////////////////////////
                    ERC721 BORROW/DEPOSIT LOGIC
  //////////////////////////////////////////////////////////////*/

  function borrow(ERC721 token, uint256 id, uint256 loanValue) external {

    require(token.ownerOf(id) == msg.sender, "NO_OWNERSHIP");
    require(token == UNDERLYING, "WRONG_UNDERLYING");
    require(loanValue <= loanToValue, "VALUE_EXCEEDED");

    USDCVault(USDCVaultAddress).useFunds(loanValue);
    token.safeTransferFrom(msg.sender, address(this), id);

    getLoanData[id].liquidationTime = block.timestamp + timeBeforeLiquidation;
    getLoanData[id].repayAmount = loanValue * (1 + interest);
    getLoanData[id].liquidationPrice = ORACLE.floorPrice().mulDivDown(1, 100);
  }
  
  function unlock(ERC721 token, uint256 id) external payable {
    
    require(token.ownerOf(id) == msg.sender, "NO_OWNERSHIP");
    require(token == UNDERLYING, "WRONG_UNDERLYING");
    require(msg.value == getLoanData[id].repayAmount, "WRONG_MSG_VALUE");

    USDCVault(USDCVaultAddress).returnFunds(msg.value);  
    token.safeTransferFrom(address(this), msg.sender, id);
  }

  function liquidate(ERC721 token, uint256 id) external {

    require(block.timestamp > getLoanData[id].liquidationTime || ORACLE.floorPrice().mulDivDown(1,100) < getLoanData[id].liquidationPrice, "LIQUIDATION_PROHIBITED");

    //TODO: Transfer to auction.
  }

  function getRepayAmount(uint256 id) public view returns(uint256) {

    require(UNDERLYING.ownerOf(id) == msg.sender, "NO_OWNERSHIP");
    
    return(getLoanData[id].repayAmount);
  }
}
