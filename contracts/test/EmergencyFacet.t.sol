// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Diamond, DiamondArgs} from "../lib/diamond-1-hardhat/contracts/Diamond.sol";
import {IDiamond} from "../lib/diamond-1-hardhat/contracts/interfaces/IDiamond.sol";
import {NotContractOwner} from "../lib/diamond-1-hardhat/contracts/libraries/LibDiamond.sol";
import {EmergencyFacet} from "../src/diamond/facets/EmergencyFacet.sol";
import {SavingsFacet} from "../src/diamond/facets/SavingsFacet.sol";
import {VaultBase} from "../src/diamond/VaultBase.sol";
import {VaultSelectors} from "../src/diamond/VaultSelectors.sol";

contract ExampleFacet {
    function value() external pure returns (uint256) { return 1; }
}

contract ReplacementFacet {
    function value() external pure returns (uint256) { return 2; }
}

contract WithdrawalReceiver {
    EmergencyFacet internal vault;
    bool internal rejectPayment;
    bool public reentryBlocked;

    constructor(address target, bool reject) {
        vault = EmergencyFacet(target);
        rejectPayment = reject;
    }

    function withdraw() external { vault.emergencyWithdraw(); }

    receive() external payable {
        require(!rejectPayment, "Payment rejected");
        (bool ok, bytes memory reason) = address(vault).call(abi.encodeCall(EmergencyFacet.emergencyWithdraw, ()));
        reentryBlocked = !ok && keccak256(reason) == keccak256(abi.encodeWithSelector(VaultBase.ReentrantCall.selector));
    }
}

contract EmergencyFacetTest is Test {
    EmergencyFacet internal emergency;
    SavingsFacet internal savings;
    address internal owner = address(0xA11CE);
    address internal user = address(0xB0B);

    function setUp() public {
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](2);
        cut[0] = IDiamond.FacetCut(address(new SavingsFacet()), IDiamond.FacetCutAction.Add, VaultSelectors.savings());
        cut[1] = IDiamond.FacetCut(address(new EmergencyFacet()), IDiamond.FacetCutAction.Add, VaultSelectors.emergency());
        Diamond diamond = new Diamond(cut, DiamondArgs(owner, address(0), ""));
        emergency = EmergencyFacet(address(diamond));
        savings = SavingsFacet(address(diamond));
    }

    function depositFor(address account, uint256 amount) internal {
        vm.deal(account, amount);
        vm.prank(account);
        savings.deposit{value: amount}(30 days);
    }

    function testEarlyWithdrawalPaysOwnerAndPreservesOtherDeposits() public {
        depositFor(user, 10 ether);
        depositFor(address(0xCAFE), 2 ether);
        vm.prank(user);
        emergency.emergencyWithdraw();
        assertEq(user.balance, 9 ether);
        assertEq(owner.balance, 1 ether);
        assertEq(address(emergency).balance, 2 ether);
        assertEq(savings.totalSaved(), 2 ether);
        (uint256 amount, uint64 unlock) = savings.savings(user);
        assertEq(amount, 0);
        assertEq(unlock, 0);
        vm.prank(user);
        vm.expectRevert(VaultBase.NothingSaved.selector);
        emergency.emergencyWithdraw();
    }

    function testFuzzPenaltyRounding(uint96 rawAmount) public {
        uint256 amount = bound(uint256(rawAmount), 1, 1_000_000 ether);
        depositFor(user, amount);
        vm.prank(user);
        emergency.emergencyWithdraw();
        assertEq(user.balance, amount - amount / 10);
        assertEq(owner.balance, amount / 10);
        assertEq(savings.totalSaved(), 0);
    }

    function testReentrancyBlocked() public {
        WithdrawalReceiver receiver = new WithdrawalReceiver(address(emergency), false);
        depositFor(address(receiver), 10 ether);
        receiver.withdraw();
        assertTrue(receiver.reentryBlocked());
        assertEq(address(receiver).balance, 9 ether);
    }

    function testRejectedUserPaymentRestoresSavings() public {
        WithdrawalReceiver receiver = new WithdrawalReceiver(address(emergency), true);
        depositFor(address(receiver), 10 ether);
        vm.expectRevert(VaultBase.TransferFailed.selector);
        receiver.withdraw();
        (uint256 amount,) = savings.savings(address(receiver));
        assertEq(amount, 10 ether);
        assertEq(savings.totalSaved(), 10 ether);
        assertEq(owner.balance, 0);
    }

    function testRejectedOwnerPaymentRestoresSavingsAndPayout() public {
        vm.etch(owner, hex"60006000fd");
        depositFor(user, 10 ether);
        vm.prank(user);
        vm.expectRevert(VaultBase.TransferFailed.selector);
        emergency.emergencyWithdraw();
        (uint256 amount,) = savings.savings(user);
        assertEq(amount, 10 ether);
        assertEq(savings.totalSaved(), 10 ether);
        assertEq(user.balance, 0);
    }

    function testNormalWithdrawalRemainsFeeFree() public {
        depositFor(user, 10 ether);
        vm.warp(block.timestamp + 30 days);
        vm.prank(user);
        savings.withdraw();
        assertEq(user.balance, 10 ether);
        assertEq(owner.balance, 0);
    }

    function testOwnerCanAddReplaceAndRemoveSelectors() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = ExampleFacet.value.selector;
        ExampleFacet first = new ExampleFacet();
        ReplacementFacet replacement = new ReplacementFacet();
        vm.prank(owner);
        emergency.addFacet(address(first), selectors);
        assertEq(ExampleFacet(address(emergency)).value(), 1);
        vm.prank(owner);
        emergency.replaceFacet(address(replacement), selectors);
        assertEq(ExampleFacet(address(emergency)).value(), 2);
        vm.prank(owner);
        emergency.removeFacet(selectors);
        (bool ok,) = address(emergency).call(abi.encodeWithSelector(ExampleFacet.value.selector));
        assertFalse(ok);
    }

    function testNonOwnerCannotManageFacets() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = ExampleFacet.value.selector;
        ExampleFacet facet = new ExampleFacet();
        bytes memory reason = abi.encodeWithSelector(NotContractOwner.selector, user, owner);
        vm.startPrank(user);
        vm.expectRevert(reason);
        emergency.addFacet(address(facet), selectors);
        vm.expectRevert(reason);
        emergency.replaceFacet(address(facet), selectors);
        vm.expectRevert(reason);
        emergency.removeFacet(selectors);
        vm.stopPrank();
    }
}
