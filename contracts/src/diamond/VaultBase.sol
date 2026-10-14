//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../../lib/diamond-1-hardhat/contracts/libraries/LibDiamond.sol";
import {LibVault} from "./libraries/LibVault.sol";

abstract contract VaultBase {
    
   error TransferFailed();
   error NothingSaved();
   error ReentrantCall();

   modifier onlyOwner() {
      LibDiamond.enforceIsContractOwner();
      _;
   }

   modifier nonReentrant() {
      LibVault.VaultStorage storage vs = LibVault.vaultStorage();
      if (vs.reentrancyLock == 1) {
         revert ReentrantCall();
      }
      vs.reentrancyLock = 1;
      _;
      vs.reentrancyLock = 0;
   }

}


