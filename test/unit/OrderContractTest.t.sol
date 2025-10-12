//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {OrderContract} from "../src/orderContract.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DeployOrderContract} from "./DeployOrderContract.s.sol";

contract OrderContractTest is Test {
    OrderContract orderContract;
    HelperConfig helperConfig;
    function setUp() public {
        DeployOrderContract deployer = new DeployOrderContract();
        (orderContract, helperConfig) = deployer.run();
        
    }
}