// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../../../lib/diamond-1-hardhat/contracts/libraries/LibDiamond.sol";
import {IDiamond} from "../../../lib/diamond-1-hardhat/contracts/interfaces/IDiamond.sol";
import {LibVault} from "../libraries/LibVault.sol";
import {VaultBase} from "../VaultBase.sol";

contract EmergencyFacet is VaultBase {
    event EmergencyWithdraw(address indexed user, uint256 payout, uint256 penalty);

    /// @notice Register the supplied selectors on a new facet. Only the diamond owner may call this.
    function addFacet(address facet, bytes4[] calldata selectors) external onlyOwner {
        _cut(facet, IDiamond.FacetCutAction.Add, selectors);
    }

    /// @notice Move existing selectors to a replacement facet.
    function replaceFacet(address facet, bytes4[] calldata selectors) external onlyOwner {
        _cut(facet, IDiamond.FacetCutAction.Replace, selectors);
    }

    /// @notice Remove the supplied selectors from the diamond.
    function removeFacet(bytes4[] calldata selectors) external onlyOwner {
        _cut(address(0), IDiamond.FacetCutAction.Remove, selectors);
    }

    /// @notice Withdraw all savings without waiting for unlock, sending a 10% penalty to the diamond owner.
    /// @dev The penalty is rounded down to whole wei; normal unlocked withdrawals remain fee-free.
    function emergencyWithdraw() external nonReentrant {
        LibVault.VaultStorage storage vs = LibVault.vaultStorage();
        LibVault.Savings storage s = vs.savings[msg.sender];
        uint256 amount = s.amount;
        if (amount == 0) revert NothingSaved();

        uint256 penalty = amount / 10;
        uint256 payout = amount - penalty;
        address owner = LibDiamond.contractOwner();
        s.amount = 0;
        s.unlockTime = 0;
        vs.totalSaved -= amount;

        emit EmergencyWithdraw(msg.sender, payout, penalty);
        (bool ok,) = payable(msg.sender).call{value: payout}("");
        if (!ok) revert TransferFailed();
        if (penalty != 0) {
            (bool feePaid,) = payable(owner).call{value: penalty}("");
            if (!feePaid) revert TransferFailed();
        }
    }

    function _cut(address facet, IDiamond.FacetCutAction action, bytes4[] memory selectors) private {
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](1);
        cut[0] = IDiamond.FacetCut(facet, action, selectors);
        LibDiamond.diamondCut(cut, address(0), "");
    }
}
