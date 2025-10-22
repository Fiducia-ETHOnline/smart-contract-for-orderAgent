// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import {OrderContract} from "../../src/OrderContract.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployOrderContract} from "script/DeployOrderContract.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {FuzzHandler} from "./Handler.t.sol";
import {A3AToken} from "../../src/A3Atoken.sol";

contract InvariantsTest is StdInvariant, Test {
    OrderContract orderContract;
    HelperConfig helperConfig;
    FuzzHandler handler;
    A3AToken token;

    function setUp() public {
        DeployOrderContract deployer = new DeployOrderContract();
        (orderContract, helperConfig,token,) = deployer.run();
        handler = new FuzzHandler(address(orderContract), address(token));
        targetContract(address(handler));
    }


    function invariantAlwaysTrue() public pure {
        assertTrue(true);
    }
}