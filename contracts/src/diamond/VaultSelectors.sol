//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IDiamondCut} from "../../lib/diamond-1-hardhat/contracts/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../../lib/diamond-1-hardhat/contracts/interfaces/IDiamondLoupe.sol";
import {IERC173} from "../../lib/diamond-1-hardhat/contracts/interfaces/IERC173.sol";
import {IERC165} from "../../lib/diamond-1-hardhat/contracts/interfaces/IERC165.sol";
import {SavingsFacet} from "./facets/SavingsFacet.sol";
import {EmergencyFacet} from "./facets/EmergencyFacet.sol";

library VaultSelectors {

    function emergency() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](4);
        s[0] = EmergencyFacet.addFacet.selector;
        s[1] = EmergencyFacet.replaceFacet.selector;
        s[2] = EmergencyFacet.removeFacet.selector;
        s[3] = EmergencyFacet.emergencyWithdraw.selector;
    }

    function diamondCut() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](1);
        s[0] = IDiamondCut.diamondCut.selector;
    }

    function diamondLoupe() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](5);
        s[0] = IDiamondLoupe.facets.selector;
        s[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        s[2] = IDiamondLoupe.facetAddresses.selector;
        s[3] = IDiamondLoupe.facetAddress.selector;
        s[4] = IERC165.supportsInterface.selector;
    }

    function ownership() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](2);
        s[0] = IERC173.owner.selector;
        s[1] = IERC173.transferOwnership.selector;
    }

    function savings() internal pure returns (bytes4[] memory s) {
        s = new bytes4[](7);
        s[0] = SavingsFacet.deposit.selector;
        s[1] = SavingsFacet.withdraw.selector;
        s[2] = SavingsFacet.setMinLockDuration.selector;
        s[3] = SavingsFacet.savings.selector;
        s[4] = SavingsFacet.totalSaved.selector;
        s[5] = SavingsFacet.minLockDuration.selector;
        s[6] = SavingsFacet.version.selector;
    }



}
