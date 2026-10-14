//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {Diamond, DiamondArgs} from "../lib/diamond-1-hardhat/contracts/Diamond.sol";
import {IDiamond} from "../lib/diamond-1-hardhat/contracts/interfaces/IDiamond.sol";
import {VaultSelectors} from "../src/diamond/VaultSelectors.sol";
import {SavingsFacet} from "../src/diamond/facets/SavingsFacet.sol";
import {EmergencyFacet} from "../src/diamond/facets/EmergencyFacet.sol";
import {VaultInit} from "../src/diamond/upgradeInitializers/VaultInit.sol";
import {OwnershipFacet} from "../lib/diamond-1-hardhat/contracts/facets/OwnershipFacet.sol";
import {DiamondLoupeFacet} from "../lib/diamond-1-hardhat/contracts/facets/DiamondLoupeFacet.sol";
import {DiamondCutFacet} from "../lib/diamond-1-hardhat/contracts/facets/DiamondCutFacet.sol";

contract DeployVaultDiamond is Script {
    function run() external returns (address vault) {
        address owner = vm.envAddress("OWNER");
        uint256 minLock = vm.envOr("MIN_LOCK", uint256(60));

        vm.startBroadcast();

        // Deploy facets
        DiamondCutFacet cutFacet = new DiamondCutFacet();
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        OwnershipFacet ownershipFacet = new OwnershipFacet();
        SavingsFacet savingsFacet = new SavingsFacet();
        EmergencyFacet emergencyFacet = new EmergencyFacet();

        VaultInit vaultInit = new VaultInit();

        // Describing the first cut
        IDiamond.FacetCut[] memory cut = new IDiamond.FacetCut[](5);

        cut[0] = IDiamond.FacetCut({
            facetAddress: address(cutFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: VaultSelectors.diamondCut()
        });
        cut[1] = IDiamond.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: VaultSelectors.diamondLoupe()
        });
        cut[2] = IDiamond.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: VaultSelectors.ownership()
        });
        cut[3] = IDiamond.FacetCut({
            facetAddress: address(savingsFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: VaultSelectors.savings()
        });

        cut[4] = IDiamond.FacetCut({
            facetAddress: address(emergencyFacet),
            action: IDiamond.FacetCutAction.Add,
            functionSelectors: VaultSelectors.emergency()
        });

        // Deploy the diamond
        DiamondArgs memory args = DiamondArgs({owner: owner, init: address(vaultInit), initCalldata: abi.encodeWithSelector(VaultInit.init.selector, minLock)});
        Diamond diamond = new Diamond(cut, args);

        vm.stopBroadcast();

        vault = address(diamond);
        console.log("DiamondCut deployed to:", address(cutFacet));
        console.log("DiamondLoupe deployed to:", address(loupeFacet));
        console.log("OwnershipFacet deployed to:", address(ownershipFacet));
        console.log("SavingsFacet deployed to:", address(savingsFacet));
        console.log("EmergencyFacet deployed to:", address(emergencyFacet));
        console.log("VAULT (Diamond) deployed to:", vault);

    }
}
