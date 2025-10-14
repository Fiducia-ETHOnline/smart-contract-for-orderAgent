// SPDX-License_Identifier: MIT


pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {OrderContract} from "../../src/OrderContract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployOrderContract} from "script/DeployOrderContract.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract InvariantsTest is StdInvariant, Test {
    OrderContract orderContract;
    HelperConfig helperConfig;

    function setUp() public {
        DeployOrderContract deployer = new DeployOrderContract();
        (orderContract, helperConfig,) = deployer.run();
        targetContract(address(orderContract));
    }


    function invariantAlwaysTrue() public pure {
        assertTrue(true);
    }
}