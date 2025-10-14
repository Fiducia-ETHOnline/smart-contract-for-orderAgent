Start Anvil:
```
anvil  
```  

Build SC:
```
forge script script/DeployOrderContract.s.sol:DeployOrderContract --rpc-url 127.0.0.1:8545 --broadcast --private-key 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
```  

Memorize:
```
== Return ==
0: contract OrderContract 0x5FbDB2315678afecb367f032d93F642f64180aa3
1: contract HelperConfig 0xC7f2Cf4845C6db0e1a1e91ED41Bcd0FcC1b0E141

== Logs ==
  pyUSD deployed at: 0x0116686E2291dbd5e317F47faDBFb43B599786Ef
```